import importlib.util
import json
import os
import sys
import uuid
from pathlib import Path

import pytest


sys.dont_write_bytecode = True


def pytest_configure(config):
    config.addinivalue_line("markers", "security: security-focused tests")


@pytest.fixture(scope="session")
def repo_root() -> Path:
    return Path(__file__).resolve().parents[1]


@pytest.fixture(scope="session")
def widget_root(repo_root: Path) -> Path:
    return repo_root / "claude-usage-widget"


def _cleanup_pycache(root: Path) -> None:
    for pyc in root.rglob("*.pyc"):
        pyc.unlink(missing_ok=True)
    for cache_dir in sorted(root.rglob("__pycache__"), reverse=True):
        try:
            cache_dir.rmdir()
        except OSError:
            pass


@pytest.fixture()
def temp_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setenv("HOME", str(home))
    return home


@pytest.fixture()
def config_dir(temp_home: Path) -> Path:
    path = temp_home / ".config" / "claude-widget"
    path.mkdir(parents=True, exist_ok=True)
    return path


@pytest.fixture()
def sample_sync_settings() -> dict:
    return {
        "colorTheme": "violet",
        "apiTimeWindow": "monthly",
        "apiCurrency": "EUR",
        "apiBudgetCap": 39,
        "apiBudgetMode": "selected",
    }


@pytest.fixture()
def sample_api_payload() -> dict:
    return {
        "mode": "api",
        "window": "monthly",
        "tokens": {"display": "59K", "input_display": "39K", "output_display": "16K", "cache_read_display": "2K"},
        "cost": {"display": "EUR0.31", "budget_display": "EUR0.31 / EUR39.00"},
        "budget": {"pct": 0.8, "has_cap": True},
        "cache_efficiency": 5,
        "by_model": [{"display": "Sonnet 4.6", "tokens_display": "59K", "cost_display": "EUR0.31", "pct": 99}],
    }


@pytest.fixture(autouse=True)
def cleanup_widget_pycache(widget_root: Path):
    _cleanup_pycache(widget_root)
    yield
    _cleanup_pycache(widget_root)


def load_module_from_path(path: Path, module_name: str | None = None):
    name = module_name or f"testmod_{path.stem}_{uuid.uuid4().hex}"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


@pytest.fixture()
def load_module(repo_root: Path):
    def _load(rel_path: str, module_name: str | None = None):
        return load_module_from_path(repo_root / rel_path, module_name)

    return _load


def run_main_and_parse(module, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture, argv: list[str]):
    monkeypatch.setattr(sys, "argv", argv)
    rc = module.main()
    out = capsys.readouterr().out.strip()
    return rc, json.loads(out)
