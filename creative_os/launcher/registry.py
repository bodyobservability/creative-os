from __future__ import annotations

from dataclasses import dataclass
from typing import List

@dataclass(frozen=True)
class AppEntry:
    id: str
    label: str
    install_cmd: List[str]
    run_cmd: List[str]
    dangerous_install: bool = True

def apps() -> list[AppEntry]:
    return [
        AppEntry(
            id="accounting",
            label="Accounting TUI",
            install_cmd=["make", "shell-install"],
            run_cmd=["make", "tui"],
            dangerous_install=True,
        ),
        AppEntry(
            id="studio",
            label="Studio Operator TUI",
            install_cmd=["make", "onboard"],
            run_cmd=["make", "studio"],
            dangerous_install=True,
        ),
    ]
