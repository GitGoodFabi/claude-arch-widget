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
        # Flatpak
        "~/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default-release/cookies.sqlite",
        "~/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default/cookies.sqlite",
    ]
    for pattern in patterns:
        for db_path in glob.glob(os.path.expanduser(pattern)):
            try:
                # Copy first — Firefox may have the DB locked
                fd, tmp = tempfile.mkstemp(suffix=".sqlite")
                os.close(fd)
                shutil.copy2(db_path, tmp)
                conn = sqlite3.connect(tmp)
                row = conn.execute(
                    "SELECT value FROM moz_cookies "
                    "WHERE host LIKE '%claude.ai%' AND name='sessionKey'"
                ).fetchone()
                conn.close()
                os.unlink(tmp)
                if row and row[0]:
                    info(f"Found in Firefox: {db_path}")
                    return row[0]
            except Exception as e:
                info(f"Firefox read error ({db_path}): {e}")
    return None


# ── Chromium-based ────────────────────────────────────────────────────────────

def _decrypt_v10(data: bytes) -> str | None:
    """Decrypt a v10/v11 Chromium cookie using Linux basic encryption (password='peanuts')."""

    # Try `cryptography` (common on Arch: python-cryptography)
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.primitives import padding
        from cryptography.hazmat.backends import default_backend
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
        from cryptography.hazmat.primitives import hashes

        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA1(),
            length=16,
            salt=b"saltysalt",
            iterations=1,
            backend=default_backend(),
        )
        key = kdf.derive(b"peanuts")
        iv = b" " * 16
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
        dec = cipher.decryptor()
        raw = dec.update(data) + dec.finalize()
        unpadder = padding.PKCS7(128).unpadder()
        return (unpadder.update(raw) + unpadder.finalize()).decode("utf-8")
    except ImportError:
        pass
    except Exception:
        pass

    # Fallback: pycryptodome
    try:
        from Crypto.Cipher import AES
        from Crypto.Protocol.KDF import PBKDF2
        import hashlib
        import hmac as hmaclib

        key = PBKDF2(
            b"peanuts",
            b"saltysalt",
            dkLen=16,
            count=1,
            prf=lambda p, s: hmaclib.new(p, s, hashlib.sha1).digest(),
        )
        cipher = AES.new(key, AES.MODE_CBC, IV=b" " * 16)
        raw = cipher.decrypt(data)
        pad_len = raw[-1]
        return raw[:-pad_len].decode("utf-8")
    except ImportError:
        pass
    except Exception:
        pass

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
    info("Searching for claude.ai sessionKey cookie...")

    key = get_firefox() or get_chromium()
    if key:
        print(key, end="")
        sys.exit(0)

    info("Cookie not found automatically.")
    sys.exit(1)


if __name__ == "__main__":
    main()
