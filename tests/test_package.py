import json
import subprocess
import zipfile
from pathlib import Path


def test_metadata_and_package_structure(repo_root, widget_root):
    metadata = json.loads((widget_root / "metadata.json").read_text())
    assert metadata["KPackageStructure"] == "Plasma/Applet"
    assert metadata["X-Plasma-API-Minimum-Version"]
    plugin = metadata["KPlugin"]
    assert plugin["Id"]
    assert plugin["Version"]
    assert plugin["Name"]
    assert plugin["License"]
    assert plugin["Keywords"]
    assert "Tags" not in plugin


def test_required_files_and_icon_exist(widget_root):
    required = [
        widget_root / "contents/ui/main.qml",
        widget_root / "contents/config/main.xml",
        widget_root / "contents/config/config.qml",
    ]
    for path in required:
        assert path.is_file()

    metadata = json.loads((widget_root / "metadata.json").read_text())
    icon_name = metadata["KPlugin"]["Icon"]
    icon_path = widget_root / "contents/icons" / f"{icon_name}.svg"
    assert icon_path.is_file()


def test_no_pycache_directories_exist(widget_root):
    assert not list(widget_root.rglob("__pycache__"))


def test_package_archive_contents(repo_root, widget_root):
    subprocess.run(["bash", "package.sh"], cwd=repo_root, check=True)
    archive = repo_root / "com.github.fabian.claude-usage.plasmoid"
    assert archive.is_file()
    with zipfile.ZipFile(archive) as zf:
        names = set(zf.namelist())
        assert "metadata.json" in names
        assert "contents/ui/main.qml" in names
        assert "contents/config/main.xml" in names
        assert "contents/config/config.qml" in names
        assert "contents/icons/claude-usage.svg" in names
        assert all("__pycache__" not in name for name in names)
        assert all(not name.endswith(".pyc") for name in names)
        assert all(not name.endswith("session.txt") for name in names)
        assert all(not name.endswith("api_key.txt") for name in names)
        assert all(not name.endswith(".txt") for name in names)
