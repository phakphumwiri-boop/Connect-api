from typing import Literal

from pydantic import BaseModel, Field, StringConstraints
from typing_extensions import Annotated


MachineMode = Literal["web", "android", "desktop"]
MachineAction = Literal["start", "stop", "restart"]

MachineName = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=1,
        max_length=48,
        pattern=r"^[a-zA-Z0-9][a-zA-Z0-9._-]*$",
    ),
]


class MachineCreate(BaseModel):
    name: MachineName
    mode: MachineMode
    cpu_cores: int = Field(default=2, ge=1, le=8)
    memory_mb: int = Field(default=4096, ge=1024, le=16384)
    # Docker storage quotas depend on the host storage driver. This is a
    # requested target and is not reported as enforced unless verified.
    disk_gb: int = Field(default=10, ge=1, le=100)
    workspace_id: str | None = Field(default=None, pattern=r"^[a-zA-Z0-9_-]{1,64}$")


class MachineResponse(BaseModel):
    id: str
    name: str
    mode: MachineMode
    status: str
    cpu_cores: int
    memory_mb: int
    disk_gb_requested: int
    disk_quota_enforced: bool
    preview_url: str | None = None
    note: str | None = None
