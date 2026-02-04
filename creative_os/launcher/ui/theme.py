from __future__ import annotations
from dataclasses import dataclass
from enum import Enum

class Mode(str, Enum):
    SAFE = "SAFE"
    GUIDED = "GUIDED"
    ALL = "ALL"

@dataclass(frozen=True)
class ModeTheme:
    badge: str

THEMES = {
    Mode.SAFE: ModeTheme(badge="[bold black on green] SAFE [/]"),
    Mode.GUIDED: ModeTheme(badge="[bold black on yellow] GUIDED [/]"),
    Mode.ALL: ModeTheme(badge="[bold white on red] ALL [/]"),
}

def theme_for(mode: Mode) -> ModeTheme:
    return THEMES[mode]
