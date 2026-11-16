import os
import secrets

from fastapi import APIRouter, Header, HTTPException, status

from app.models.machine_models import MachineAction, MachineCreate, MachineResponse
from app.services import machine_service


router = APIRouter(prefix="/machines", tags=["machines"])


def _authorize(x_admin_token: str | None):
    expected = os.getenv("CONNECT_API_ADMIN_TOKEN")
    if not expected:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Machine management is disabled: configure CONNECT_API_ADMIN_TOKEN.",
        )
    if not x_admin_token or not secrets.compare_digest(x_admin_token, expected):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admin token.")


def _translate_error(exc):
    message = str(exc)
    code = 503 if isinstance(exc, machine_service.RuntimeUnavailable) else 400
    if isinstance(exc, machine_service.MachineNotFound):
        code = 404
    raise HTTPException(status_code=code, detail=message) from exc


@router.post("", response_model=MachineResponse, status_code=status.HTTP_201_CREATED)
def create_machine(payload: MachineCreate, x_admin_token: str | None = Header(default=None)):
    _authorize(x_admin_token)
    try:
        return machine_service.create_machine(payload)
    except machine_service.MachineServiceError as exc:
        _translate_error(exc)


@router.get("", response_model=list[MachineResponse])
def list_machines(x_admin_token: str | None = Header(default=None)):
    _authorize(x_admin_token)
    try:
        return machine_service.list_machines()
    except machine_service.MachineServiceError as exc:
        _translate_error(exc)


@router.get("/{machine_id}", response_model=MachineResponse)
def get_machine(machine_id: str, x_admin_token: str | None = Header(default=None)):
    _authorize(x_admin_token)
    try:
        return machine_service.get_machine(machine_id)
    except machine_service.MachineServiceError as exc:
        _translate_error(exc)


@router.post("/{machine_id}/{action}", response_model=MachineResponse)
def control_machine(
    machine_id: str,
    action: MachineAction,
    x_admin_token: str | None = Header(default=None),
):
    _authorize(x_admin_token)
    try:
        return machine_service.control_machine(machine_id, action)
    except machine_service.MachineServiceError as exc:
        _translate_error(exc)


@router.delete("/{machine_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_machine(machine_id: str, x_admin_token: str | None = Header(default=None)):
    _authorize(x_admin_token)
    try:
        machine_service.delete_machine(machine_id)
    except machine_service.MachineServiceError as exc:
        _translate_error(exc)
