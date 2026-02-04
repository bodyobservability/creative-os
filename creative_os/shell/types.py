from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional

class Mode(str, Enum):
    SAFE = "SAFE"
    GUIDED = "GUIDED"
    ALL = "ALL"

@dataclass(frozen=True)
class Action:
    id: str
    label: str
    description: str = ""
    dangerous: bool = False
    key: Optional[str] = None
    tags: List[str] = field(default_factory=list)

@dataclass(frozen=True)
class Check:
    id: str
    label: str
    ok: bool
    detail: str = ""

@dataclass(frozen=True)
class Plan:
    id: str
    action_id: str
    summary: str
    diff: List[str] = field(default_factory=list)

@dataclass(frozen=True)
class Receipt:
    id: str
    action_id: str
    status: str
    summary: str
    artifacts: List[str] = field(default_factory=list)

@dataclass(frozen=True)
class StateSummary:
    title: str
    stats: Dict[str, Any] = field(default_factory=dict)
    recommended_action_id: Optional[str] = None
