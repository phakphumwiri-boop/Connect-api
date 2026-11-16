import pytest
from fastapi import HTTPException

from app.routes.machines import _authorize


def test_machine_api_fails_closed_without_configured_token(monkeypatch):
    monkeypatch.delenv("CONNECT_API_ADMIN_TOKEN", raising=False)
    with pytest.raises(HTTPException) as error:
        _authorize("anything")
    assert error.value.status_code == 503


def test_machine_api_rejects_wrong_token(monkeypatch):
    monkeypatch.setenv("CONNECT_API_ADMIN_TOKEN", "expected-secret")
    with pytest.raises(HTTPException) as error:
        _authorize("wrong-secret")
    assert error.value.status_code == 401


def test_machine_api_accepts_configured_token(monkeypatch):
    monkeypatch.setenv("CONNECT_API_ADMIN_TOKEN", "expected-secret")
    _authorize("expected-secret")
