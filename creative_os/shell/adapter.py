from __future__ import annotations
from abc import ABC, abstractmethod
from typing import List, Optional

from .types import Action, Check, Mode, Plan, Receipt, StateSummary

class OperatorShellAdapter(ABC):
    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    def get_state(self) -> StateSummary: ...

    @abstractmethod
    def run_checks(self) -> List[Check]: ...

    @abstractmethod
    def list_actions(self, mode: Mode) -> List[Action]: ...

    @abstractmethod
    def plan(self, action_id: str) -> Plan: ...

    @abstractmethod
    def apply(self, action_id: str) -> Receipt: ...

    @abstractmethod
    def tail_logs(self, receipt_id: Optional[str] = None) -> str: ...
