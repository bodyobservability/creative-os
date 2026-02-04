from __future__ import annotations
import sys
from pathlib import Path

from .ui.app import OperatorShellApp
from .adapters import get_adapter

def main() -> None:
    repo_root = Path.cwd()
    persona = sys.argv[1] if len(sys.argv) > 1 else "accounting"
    adapter = get_adapter(persona, repo_root)
    app = OperatorShellApp(adapter)
    app.run()

if __name__ == "__main__":
    main()
