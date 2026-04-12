#!/usr/bin/env python3
"""Extracts the claude.ai sessionKey cookie from Firefox or Chromium-based browsers.

Prints only the cookie value to stdout on success.
Status/debug messages go to stderr so they don't pollute the captured output.
Exit code 0 = found, 1 = not found.
"""

import os
import sys
import glob
import sqlite3
import shutil
import tempfile


def info(msg):
    print(f"  {msg}", file=sys.stderr)


# ── Firefox ───────────────────────────────────────────────────────────────────

def get_firefox():
    patterns = [
        "~/.mozilla/firefox/*.default-release/cookies.sqlite",
        "~/.mozilla/firefox/*.default/cookies.sqlite",
        # XDG_CONFIG_HOME layout (e.g. Arch with custom XDG config)
        "~/.config/mozilla/firefox/*.default-release/cookies.sqlite",
        "~/.config/mozilla/firefox/*.default/cookies.sqlite",
        # Flatpak
        "~/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default-release/cookies.sqlite",
        "~/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default/cookies.sqlite",
    ]
    for pattern in patterns:
        for db_path in glob.glob(os.path.expanduser(pattern)):
            try:
                # Copy the DB *and* WAL/SHM sidecars into a temp dir so SQLite
                # sees a consistent snapshot even while Firefox is running.
                # Without the -wal file, cookies written since the last WAL
                # checkpoint are invisible (the most common failure mode).
                tmp_dir = tempfile.mkdtemp()
                tmp = os.path.join(tmp_dir, "cookies.sqlite")
                shutil.copy2(db_path, tmp)
                for ext in ("-wal", "-shm"):
                    src = db_path + ext
                    if os.path.exists(src):
                        shutil.copy2(src, tmp + ext)
                conn = sqlite3.connect(tmp)
                row = conn.execute(
                    "SELECT value FROM moz_cookies "
                    "WHERE host LIKE '%claude.ai%' AND name='sessionKey'"
                ).fetchone()
                conn.close()
                shutil.rmtree(tmp_dir, ignore_errors=True)
                if row and row[0]:
                    info(f"Found in Firefox: {db_path}")
                    return row[0]
            except Exception as e:
                info(f"Firefox read error ({db_path}): {e}")
    return None


# ── Chromium-based ────────────────────────────────────────────────────────────

def _get_chrome_keyring_password() -> bytes | None:
    """Try to retrieve the Chrome Safe Storage key from the system keyring.

    On KDE, Chrome stores the actual AES key in KWallet via the Secret Service
    API. 'secret-tool' (libsecret) speaks that API and works with both KWallet
    and GNOME Keyring. We try several known label/attribute combinations that
    different Chrome/Chromium builds use.
    """
    import subprocess

    queries = [
        # Chrome / Chromium / Brave use these Secret Service labels
        ["secret-tool", "lookup", "Label", "Chrome Safe Storage"],
        ["secret-tool", "lookup", "Label", "Chromium Safe Storage"],
        ["secret-tool", "lookup", "Label", "Brave Safe Storage"],
        # Fallback: attribute-based lookup
        ["secret-tool", "lookup", "application", "chrome"],
        ["secret-tool", "lookup", "application", "chromium"],
    ]
    for cmd in queries:
        try:
            result = subprocess.run(
                cmd, capture_output=True, timeout=5
            )
            pw = result.stdout.strip()
            if pw:
                info(f"Got Chrome keyring password via: {' '.join(cmd[2:])}")
                return pw
        except (FileNotFoundError, subprocess.TimeoutExpired):
            break  # secret-tool not installed — no point retrying
        except Exception:
            continue
    return None


def _derive_key(password: bytes) -> bytes:
    """PBKDF2-SHA1 with Chromium's fixed salt and 1 iteration → 16-byte AES key."""
    import hashlib
    return hashlib.pbkdf2_hmac("sha1", password, b"saltysalt", 1, dklen=16)


def _aes_cbc_decrypt(key: bytes, data: bytes) -> str | None:
    """AES-128-CBC decrypt with IV=spaces, PKCS7 unpad, return UTF-8 string."""
    iv = b" " * 16

    # Try `cryptography` (common on Arch: python-cryptography)
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.primitives import padding
        from cryptography.hazmat.backends import default_backend

        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        dec = cipher.decryptor()
        raw = dec.update(data) + dec.finalize()
        unpadder = padding.PKCS7(128).unpadder()
        return (unpadder.update(raw) + unpadder.finalize()).decode("utf-8")
    except ImportError:
        pass
    except Exception:
        return None

    # Fallback: pycryptodome
    try:
        from Crypto.Cipher import AES
        cipher = AES.new(key, AES.MODE_CBC, IV=iv)
        raw = cipher.decrypt(data)
        pad_len = raw[-1]
        return raw[:-pad_len].decode("utf-8")
    except ImportError:
        pass
    except Exception:
        pass

    return None


# Cache the keyring password so we only query it once across all browser profiles
_keyring_password: bytes | None | bool = False   # False = not yet tried


def _decrypt_v10(data: bytes) -> str | None:
    """Decrypt a v10/v11 Chromium cookie.

    Tries the system keyring key first (KWallet / GNOME Keyring via secret-tool),
    then falls back to the hardcoded 'peanuts' password used when no keyring
    is configured.
    """
    global _keyring_password
    if _keyring_password is False:
        _keyring_password = _get_chrome_keyring_password()

    candidates = []
    if _keyring_password:
        candidates.append(("keyring", _keyring_password))
    candidates.append(("peanuts", b"peanuts"))

    for label, pw in candidates:
        key = _derive_key(pw)
        result = _aes_cbc_decrypt(key, data)
        if result is not None:
            info(f"Decrypted cookie using {label} key")
            return result

    return None


def get_chromium():
    browsers = [
        ("Chrome",            "~/.config/google-chrome/Default/Cookies"),
        ("Chromium",          "~/.config/chromium/Default/Cookies"),
        ("Brave",             "~/.config/brave-browser/Default/Cookies"),
        ("Edge",              "~/.config/microsoft-edge/Default/Cookies"),
        ("Chrome (Flatpak)",  "~/.var/app/com.google.Chrome/config/google-chrome/Default/Cookies"),
        ("Chromium (Flatpak)","~/.var/app/org.chromium.Chromium/config/chromium/Default/Cookies"),
    ]
    for name, pattern in browsers:
        db_path = os.path.expanduser(pattern)
        if not os.path.exists(db_path):
            continue
        info(f"Checking {name}...")
        try:
            fd, tmp = tempfile.mkstemp(suffix=".sqlite")
            os.close(fd)
            shutil.copy2(db_path, tmp)
            conn = sqlite3.connect(tmp)
            rows = conn.execute(
                "SELECT value, encrypted_value FROM cookies "
                "WHERE host_key LIKE '%claude.ai%' AND name='sessionKey'"
            ).fetchall()
            conn.close()
            os.unlink(tmp)

            for value, enc_value in rows:
                if value:
                    info(f"Found (plain) in {name}")
                    return value
                if enc_value:
                    prefix = enc_value[:3]
                    if prefix in (b"v10", b"v11"):
                        decrypted = _decrypt_v10(enc_value[3:])
                        if decrypted:
                            info(f"Found (decrypted v10) in {name}")
                            return decrypted
                        info(
                            f"{name}: cookie uses keyring encryption — "
                            "use Firefox or paste the key manually"
                        )
        except Exception as e:
            info(f"{name} read error: {e}")
    return None


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    info("Searching for claude.ai sessionKey cookie in Firefox and Chromium-based browsers...")

    key = get_firefox() or get_chromium()
    if key:
        print(key, end="")
        sys.exit(0)

    info("Cookie not found automatically.")
    info("Checked: Firefox, Chrome, Chromium, Brave, Edge (native + Flatpak).")
    info("If you use a different browser, paste the session key manually.")
    sys.exit(1)


if __name__ == "__main__":
    main()
