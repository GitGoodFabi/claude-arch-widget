import os
import subprocess


def test_setup_and_package_scripts_are_valid_bash(repo_root):
    setup_path = repo_root / "setup.sh"
    package_path = repo_root / "package.sh"
    assert os.access(setup_path, os.X_OK)
    subprocess.run(["bash", "-n", str(setup_path)], check=True)
    subprocess.run(["bash", "-n", str(package_path)], check=True)


def test_package_script_produces_plasmoid(repo_root):
    subprocess.run(["bash", "package.sh"], cwd=repo_root, check=True)
    assert (repo_root / "com.github.fabian.claude-usage.plasmoid").is_file()
