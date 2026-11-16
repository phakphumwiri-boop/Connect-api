import pytest
from pydantic import ValidationError

from app.models.machine_models import MachineCreate


@pytest.mark.parametrize("mode", ["web", "android", "desktop"])
def test_machine_modes_are_supported(mode):
    machine = MachineCreate(name="test-machine", mode=mode)
    assert machine.mode == mode
    assert machine.cpu_cores == 2
    assert machine.memory_mb == 4096


def test_machine_resource_limits_accept_supported_values():
    machine = MachineCreate(
        name="ci-runner",
        mode="desktop",
        cpu_cores=8,
        memory_mb=16384,
        disk_gb=100,
    )
    assert machine.cpu_cores == 8
    assert machine.memory_mb == 16384
    assert machine.disk_gb == 100


@pytest.mark.parametrize(
    "payload",
    [
        {"name": "bad name", "mode": "web"},
        {"name": "../escape", "mode": "web"},
        {"name": "vm", "mode": "unknown"},
        {"name": "vm", "mode": "web", "cpu_cores": 0},
        {"name": "vm", "mode": "web", "memory_mb": 128},
        {"name": "vm", "mode": "web", "disk_gb": 1000},
    ],
)
def test_invalid_machine_requests_are_rejected(payload):
    with pytest.raises(ValidationError):
        MachineCreate(**payload)
