from __future__ import annotations

from pathlib import Path
from typing import Callable, Dict

from ..adapter import OperatorShellAdapter

_REGISTRY: Dict[str, Callable[[Path], OperatorShellAdapter]] = {}

def register_adapter(name: str, factory: Callable[[Path], OperatorShellAdapter]) -> None:
    _REGISTRY[name] = factory

def get_adapter(name: str, repo_root: Path) -> OperatorShellAdapter:
    if name not in _REGISTRY:
        raise KeyError(f"Unknown persona adapter: {name}. Registered: {sorted(_REGISTRY.keys())}")
    return _REGISTRY[name](repo_root)

from .accounting import AccountingShellAdapter  # noqa: E402
register_adapter("accounting", lambda repo_root: AccountingShellAdapter(repo_root))
