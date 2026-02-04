from __future__ import annotations

from pathlib import Path
from typing import List, Optional
import time

from ..adapter import OperatorShellAdapter
from ..runner import CommandRunner
from ..types import Action, Check, Mode, Plan, Receipt, StateSummary

CONFIG_LIVE = Path("CONFIG/corp_payment_fingerprints.json")
BUNDLES_DIR = Path("accounting/2025/bundles")
DRY_RUN_MARKER = Path("accounting/.local/ui_state/dry_run_done_2025")

EXPORT_FILES = [
    Path("schedule_c_expenses_2025.csv"),
    Path("corp_reimbursable_expenses_2025.csv"),
    Path("sole_prop_assets_retained_2025.csv"),
    Path("sole_prop_assets_for_sale_2026.csv"),
    Path("corp_asset_intake_2026.csv"),
]

def _newest_mtime_under(root: Path, patterns: tuple[str, ...]) -> float:
    if not root.exists():
        return 0.0
    newest = 0.0
    for pat in patterns:
        for f in root.rglob(pat):
            try:
                newest = max(newest, f.stat().st_mtime)
            except FileNotFoundError:
                pass
    return newest

def _newest_bundle_change_mtime() -> float:
    return max(
        _newest_mtime_under(BUNDLES_DIR, ("decisions/*.json",)),
        _newest_mtime_under(BUNDLES_DIR, ("extracted/extracted_metadata.json",)),
    )

def _exports_mtime() -> float:
    mtimes = []
    for f in EXPORT_FILES:
        if not f.exists():
            return 0.0
        try:
            mtimes.append(f.stat().st_mtime)
        except FileNotFoundError:
            return 0.0
    return min(mtimes) if mtimes else 0.0

def _exports_stale() -> bool:
    return _exports_mtime() < _newest_bundle_change_mtime()

def _autofill_has_run() -> bool:
    if not BUNDLES_DIR.exists():
        return False
    for f in BUNDLES_DIR.rglob("decisions/auto_owner_from_payment.json"):
        return True
    return False

def _dry_run_done() -> bool:
    return DRY_RUN_MARKER.exists()

def _mark_dry_run_done() -> None:
    DRY_RUN_MARKER.parent.mkdir(parents=True, exist_ok=True)
    DRY_RUN_MARKER.write_text("ok\n")

def _backup_snapshot_exists_recently(max_age_hours: int = 48) -> bool:
    snap_dir = Path("accounting/_snapshots")
    if not snap_dir.exists():
        return False
    newest = _newest_mtime_under(snap_dir, ("*.zip",))
    if newest == 0:
        return False
    return (time.time() - newest) < (max_age_hours * 3600)

class AccountingShellAdapter(OperatorShellAdapter):
    def __init__(self, repo_root: Path):
        self._runner = CommandRunner(repo_root)
        self._last_log: str = ""

    @property
    def name(self) -> str:
        return "accounting"

    def get_state(self) -> StateSummary:
        r_status = self._runner.make("status")
        status_txt = (r_status.stdout or "") + ("\n" + r_status.stderr if r_status.stderr else "")
        self._last_log = status_txt

        recommended: Optional[str] = None
        reason = ""

        if not CONFIG_LIVE.exists():
            recommended = "init-config"
            reason = "Missing CONFIG/corp_payment_fingerprints.json"
        else:
            if not _autofill_has_run():
                if not _dry_run_done():
                    recommended = "dry-run"
                    reason = "Preview corp-card matches before applying autofill"
                else:
                    recommended = "autofill"
                    reason = "Apply autofill now that you’ve previewed matches"
            else:
                r_ci = self._runner.make("ci")
                if r_ci.returncode != 0:
                    recommended = "ci"
                    reason = "economic_owner incomplete — classify remaining bundles"
                    self._last_log = (r_ci.stdout or "") + ("\n" + r_ci.stderr if r_ci.stderr else "")
                else:
                    if _exports_stale():
                        recommended = "exports"
                        reason = "Exports missing or stale vs newest decisions/metadata"
                    else:
                        # Backup by default in GUIDED and ALL: recommend dry-run first
                        if not _backup_snapshot_exists_recently():
                            recommended = "backup-dry"
                            reason = "Preview backup sync (recommended after exports)"
                        else:
                            recommended = "backup"
                            reason = "Back up evidence to Drive"

        stats = {
            "status_output": status_txt.strip(),
            "next_reason": reason,
            "exports_stale": _exports_stale(),
            "last_bundle_change_mtime": _newest_bundle_change_mtime(),
            "exports_mtime": _exports_mtime(),
        }

        return StateSummary(
            title="Accounting (2025)",
            stats=stats,
            recommended_action_id=recommended,
        )

    def run_checks(self) -> List[Check]:
        r = self._runner.make("ci")
        ok = (r.returncode == 0)
        detail = (r.stdout or "") + ("\n" + r.stderr if r.stderr else "")
        self._last_log = detail
        return [Check(id="economic_owner_complete", label="economic_owner fully classified", ok=ok, detail=detail.strip())]

    def list_actions(self, mode: Mode) -> List[Action]:
        actions = [
            Action(id="init-config", label="Init config", description="Copy config template -> live config", dangerous=False, key="1"),
            Action(id="dry-run", label="Autofill dry-run", description="Preview corp-card matches", dangerous=False, key="2"),
            Action(id="autofill", label="Autofill apply", description="Write decisions + safe metadata updates", dangerous=True, key="3"),
            Action(id="ci", label="Run CI check", description="Fail if economic_owner missing", dangerous=False, key="4"),
            Action(id="exports", label="Generate exports", description="Write Schedule C + asset + corp intake CSVs", dangerous=True, key="5"),
            Action(id="backup-dry", label="Backup dry-run", description="Preview Drive sync", dangerous=False, key="6"),
            Action(id="backup", label="Backup sync", description="Sync local evidence to Drive", dangerous=True, key="7"),
            Action(id="backup-zip", label="Backup snapshot zip", description="Zip snapshot then upload", dangerous=True, key="8"),
            Action(id="seal-epoch", label="Seal epoch (stub)", description="Writes a local seal marker; does not modify evidence", dangerous=True, key="9"),
        ]
        if mode == Mode.SAFE:
            return [a for a in actions if not a.dangerous]
        if mode == Mode.GUIDED:
            return [a for a in actions if a.id != "seal-epoch"]
        return actions

    def plan(self, action_id: str) -> Plan:
        if action_id == "seal-epoch":
            diff = [
                "Will write: accounting/epochs/2025/SEALED.marker (local-only marker)",
                "Will NOT modify: bundles, originals, exports (no changes)",
                "",
                "Intended use: record that you consider 2025 closed after filing.",
            ]
            return Plan(id="plan-seal-epoch", action_id=action_id, summary="Preview seal epoch (stub)", diff=diff)

        if action_id == "dry-run":
            r = self._runner.make("dry-run")
            diff = (r.stdout or "").splitlines()
            self._last_log = (r.stdout or "") + ("\n" + r.stderr if r.stderr else "")
            return Plan(id="plan-dry-run", action_id=action_id, summary="Preview corp-card matches", diff=diff[:200])

        if action_id == "backup-dry":
            r = self._runner.make("backup-dry")
            diff = (r.stdout or "").splitlines()
            self._last_log = (r.stdout or "") + ("\n" + r.stderr if r.stderr else "")
            return Plan(id="plan-backup-dry", action_id=action_id, summary="Preview backup sync", diff=diff[:200])

        if action_id == "exports":
            csvs = [str(p) for p in EXPORT_FILES]
            diff = [f"Will write: {name}" for name in csvs] + ["", "Notes:", "- Files are generated locally (gitignored)."]
            return Plan(id="plan-exports", action_id=action_id, summary="Preview exports to be generated", diff=diff)

        return Plan(id=f"plan-{action_id}", action_id=action_id, summary="No explicit plan; execute to proceed.", diff=[])

    def apply(self, action_id: str) -> Receipt:
        if action_id == "seal-epoch":
            marker = Path("accounting/epochs/2025/SEALED.marker")
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text("sealed\n")
            self._last_log = f"SEALED marker written: {marker}\n"
            return Receipt(
                id="receipt-seal-epoch",
                action_id=action_id,
                status="ok",
                summary="seal-epoch -> ok (stub)",
                artifacts=[str(marker)],
            )

        r = self._runner.make(action_id)
        out = (r.stdout or "") + ("\n" + r.stderr if r.stderr else "")
        self._last_log = out
        status = "ok" if r.returncode == 0 else "error"

        if action_id == "dry-run" and status == "ok":
            _mark_dry_run_done()

        artifacts = []
        if action_id == "exports" and status == "ok":
            artifacts = [str(p) for p in EXPORT_FILES]

        return Receipt(
            id=f"receipt-{action_id}",
            action_id=action_id,
            status=status,
            summary=f"{action_id} -> {status}",
            artifacts=artifacts,
        )

    def tail_logs(self, receipt_id: Optional[str] = None) -> str:
        return self._last_log.strip()
