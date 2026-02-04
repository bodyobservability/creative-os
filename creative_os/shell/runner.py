from __future__ import annotations
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional

@dataclass(frozen=True)
class RunResult:
    returncode: int
    stdout: str
    stderr: str

class CommandRunner:
    def __init__(self, repo_root: Path):
        self.repo_root = repo_root

    def run(self, cmd: list[str], env_overrides: Optional[Dict[str, str]] = None, timeout_s: Optional[int] = None) -> RunResult:
        env = os.environ.copy()
        if env_overrides:
            env.update(env_overrides)
        p = subprocess.run(cmd, cwd=str(self.repo_root), env=env, text=True, capture_output=True, timeout=timeout_s)
        return RunResult(p.returncode, p.stdout, p.stderr)

    def make(self, target: str, extra_env: Optional[Dict[str, str]] = None) -> RunResult:
        return self.run(["make", target], env_overrides=extra_env)
