from __future__ import annotations

import os
import subprocess
import shutil
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import Header, Footer, Static, ListView, ListItem

from ..registry import apps, AppEntry
from .theme import Mode, theme_for

# ---------- install heuristics (repo-relative) ----------
def is_accounting_installed() -> bool:
    return Path(".venv/bin/python").exists()

def is_studio_installed() -> bool:
    return Path("kernel/cli/.build/release/wub").exists()

def installed_for(entry: AppEntry) -> bool:
    if entry.id == "accounting":
        return is_accounting_installed()
    if entry.id == "studio":
        return is_studio_installed()
    return False

def status_badge(ok: bool) -> str:
    return "[green]●[/]" if ok else "[red]○[/]"

# ---------- repo status checks ----------
def which(cmd: str) -> bool:
    return shutil.which(cmd) is not None

# ---------- accounting ingestion readiness ----------
def mbox_present() -> bool:
    # Prefer local-only root
    roots = [
        Path("accounting/data/2025/intake"),
        Path("accounting/2025/intake"),
    ]
    for r in roots:
        if r.exists() and any(r.rglob("*.mbox")):
            return True
    return False

def extracted_mail_present() -> bool:
    roots = [
        Path("accounting/data/2025/intake"),
        Path("accounting/2025/intake"),
    ]
    for r in roots:
        if not r.exists():
            continue
        # any eml or pdf/image attachment indicates extraction has begun
        if any(r.rglob("*.eml")):
            return True
        if any(r.rglob("*.pdf")) or any(r.rglob("*.png")) or any(r.rglob("*.jpg")) or any(r.rglob("*.jpeg")):
            return True
    return False

def bundles_present() -> bool:
    p = Path("accounting/data/2025/bundles")
    return p.exists() and any(p.iterdir())

def intake_folder() -> Path:
    # Prefer local-only root if exists, else default
    p = Path("accounting/data/2025/intake")
    return p if p.exists() else Path("accounting/2025/intake")

def bundles_folder() -> Path:
    return Path("accounting/data/2025/bundles")

def open_folder(path: Path) -> str:
    # Best-effort opener; returns status text.
    try:
        if os.name == "nt":
            os.startfile(str(path))  # type: ignore[attr-defined]
        elif shutil.which("open"):
            subprocess.run(["open", str(path)])
        elif shutil.which("xdg-open"):
            subprocess.run(["xdg-open", str(path)])
        else:
            return f"No opener found. Folder: {path}"
        return f"Opened folder: {path}"
    except Exception as e:
        return f"Failed to open folder {path}: {e}"

def repo_status_lines() -> list[str]:
    lines = []
    lines.append(f"{status_badge(which('make'))} make")
    lines.append(f"{status_badge(which('python3') or which('python'))} python")
    lines.append(f"{status_badge(which('rclone'))} rclone (optional for backups)")

    # Accounting readiness
    cfg = Path("CONFIG/corp_payment_fingerprints.json")
    lines.append("")
    lines.append("[bold]Accounting readiness[/]")
    lines.append(f"{status_badge(cfg.exists())} CONFIG/corp_payment_fingerprints.json (local)")
    lines.append(f"{status_badge(bundles_present())} accounting/data/2025/bundles/")

    lines.append("")
    lines.append("[bold]Accounting ingestion[/]")
    lines.append(f"{status_badge(mbox_present())} Gmail Takeout (.mbox) present")
    lines.append(f"{status_badge(extracted_mail_present())} Intake extracted (.eml / attachments)")
    lines.append(f"{status_badge(bundles_present())} Bundles created")

    return lines

def ingestion_plan_lines() -> list[str]:
    return [
        "[bold]Ingestion plan (manual, minimal)[/]",
        "1) Export Gmail via Google Takeout (.mbox) for 2025",
        f"2) Place .mbox under: {intake_folder()}",
        "3) Extract .eml + attachments into intake/ (keep originals)",
        f"4) Create bundles under: {bundles_folder()} (per Bundle 01 spec)",
        "",
        "Tip: over-capture is OK; dedupe via hashes.",
    ]

def global_recommendation(entries: list[AppEntry]) -> tuple[str, str]:
    # Ingestion-aware recommendations first
    if not mbox_present():
        return ("show:ingestion-plan", "No Gmail Takeout (.mbox) found")
    if mbox_present() and not extracted_mail_present():
        return ("open:intake", "Place/extract .eml + attachments into intake")
    if extracted_mail_present() and not bundles_present():
        return ("open:bundles", "Bundles missing; create bundles from intake")
    # Install/run persona apps
    for e in entries:
        if not installed_for(e):
            return (f"install:{e.id}", f"{e.label} not installed")
    if entries:
        return (f"run:{entries[0].id}", f"{entries[0].label} ready")
    return ("", "No apps registered")

class EntryItem(ListItem):
    def __init__(self, label: str, entry: AppEntry, installed: bool):
        super().__init__(Static(label))
        self.entry = entry
        self.installed = installed

class LauncherApp(App):
    BINDINGS = [
        Binding("m", "toggle_mode", "Mode"),
        Binding("enter", "run_selected", "Run"),
        Binding("i", "install_selected", "Install"),
        Binding("space", "recommended", "Next"),
        Binding("p", "plan", "Plan"),
        Binding("o", "open_selected", "Open Folder"),
        Binding("r", "refresh", "Refresh"),
        Binding("q", "quit", "Quit"),
        Binding("y", "confirm", "Confirm", show=False),
        Binding("n", "cancel", "Cancel", show=False),
        Binding("1", "run_n(1)", "1"),
        Binding("2", "run_n(2)", "2"),
        Binding("3", "run_n(3)", "3"),
        Binding("4", "run_n(4)", "4"),
        Binding("5", "run_n(5)", "5"),
        Binding("6", "run_n(6)", "6"),
        Binding("7", "run_n(7)", "7"),
        Binding("8", "run_n(8)", "8"),
        Binding("9", "run_n(9)", "9"),
    ]

    def __init__(self):
        super().__init__()
        self.mode: Mode = Mode.SAFE
        self._entries: list[AppEntry] = apps()
        self._armed_install: AppEntry | None = None
        self._last_log: str = ""

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical(id="left"):
                yield Static("", id="mode_bar")
                yield ListView(id="entries")
            with Vertical(id="right"):
                yield Static("", id="repo_status")
                yield Static("", id="detail")
                yield Static("", id="log")
                yield Static("", id="prompt")
        yield Footer()

    def on_mount(self) -> None:
        self.refresh_ui()

    def refresh_ui(self) -> None:
        t = theme_for(self.mode)
        entries = apps()
        rec_action, rec_reason = global_recommendation(entries)
        rec_text = f"[bold]Next:[/] {rec_action or '—'} [dim]{rec_reason}[/]"

        self.query_one("#mode_bar", Static).update(
            f"[LAUNCHER] {t.badge}  Space=Next  Enter=Run  i=Install  o=Open  p=Plan  m=Mode  (SAFE hides installs)   {rec_text}"
        )

        lv = self.query_one("#entries", ListView)
        lv.clear()
        self._entries = entries
        for idx, e in enumerate(self._entries, start=1):
            key = str(idx) if idx <= 9 else ""
            inst = installed_for(e)
            badge = status_badge(inst)
            hint = "run" if inst else "install"
            lv.append(EntryItem(f"{key}. {badge} {e.label}  [dim](next: {hint})[/]", e, inst))

        self.query_one("#repo_status", Static).update("\n".join(["[bold]Repo status[/]"] + repo_status_lines()))
        self._render_detail()
        self.query_one("#log", Static).update(self._last_log.strip())
        self.query_one("#prompt", Static).update("")
        self._armed_install = None

    def _render_detail(self) -> None:
        e = self._selected()
        if not e:
            self.query_one("#detail", Static).update(
                "Select an app. Space runs the global next step.\n"
                "Use p for the ingestion plan and o to open intake/bundles."
            )
            return
        inst = installed_for(e)
        next_step = "run" if inst else "install"
        detail = [
            f"[bold]{e.label}[/]",
            f"Installed: {'yes' if inst else 'no'}",
            f"Next: {next_step} (Space)",
            "",
            f"Install: {' '.join(e.install_cmd)}",
            f"Run:     {' '.join(e.run_cmd)}",
            "",
            "Exec replacement: running an app replaces the launcher process.",
        ]
        self.query_one("#detail", Static).update("\n".join(detail))

    def _selected(self) -> AppEntry | None:
        lv = self.query_one("#entries", ListView)
        item = lv.highlighted_child
        if isinstance(item, EntryItem):
            return item.entry
        return None

    def action_toggle_mode(self) -> None:
        self.mode = Mode.GUIDED if self.mode == Mode.SAFE else (Mode.ALL if self.mode == Mode.GUIDED else Mode.SAFE)
        self.refresh_ui()

    def action_refresh(self) -> None:
        self.refresh_ui()

    def action_plan(self) -> None:
        # Show ingestion plan regardless of selection.
        self._last_log = "\n".join(ingestion_plan_lines())
        self.refresh_ui()

    def action_open_selected(self) -> None:
        # Open relevant folder based on ingestion state
        if not mbox_present() or not extracted_mail_present():
            self._last_log = open_folder(intake_folder())
        else:
            self._last_log = open_folder(bundles_folder())
        self.refresh_ui()

    def action_recommended(self) -> None:
        e = self._selected()
        if e:
            if installed_for(e):
                self._exec_replace(e.run_cmd)
            else:
                self.action_install_selected()
            return

        # Global recommendation
        entries = self._entries or apps()
        rec_action, _ = global_recommendation(entries)
        if not rec_action:
            return

        if rec_action == "show:ingestion-plan":
            self.action_plan()
            return
        if rec_action == "open:intake":
            self._last_log = open_folder(intake_folder())
            self.refresh_ui()
            return
        if rec_action == "open:bundles":
            self._last_log = open_folder(bundles_folder())
            self.refresh_ui()
            return

        kind, app_id = rec_action.split(":", 1)
        target = next((x for x in entries if x.id == app_id), None)
        if not target:
            return
        if kind == "run":
            self._exec_replace(target.run_cmd)
        else:
            if self.mode == Mode.SAFE:
                self.query_one("#prompt", Static).update("[dim]Install hidden in SAFE. Press m for GUIDED/ALL.[/]")
                return
            if self.mode == Mode.ALL and target.dangerous_install:
                self._armed_install = target
                self.query_one("#prompt", Static).update(
                    f"[bold red]Install armed:[/] {' '.join(target.install_cmd)}\nPress y to confirm, n to cancel."
                )
                return
            self._run_install(target)

    def action_run_selected(self) -> None:
        e = self._selected()
        if not e:
            return
        self._exec_replace(e.run_cmd)

    def action_run_n(self, n: int) -> None:
        if 1 <= n <= len(self._entries):
            self._exec_replace(self._entries[n-1].run_cmd)

    def action_install_selected(self) -> None:
        e = self._selected()
        if not e:
            return
        if self.mode == Mode.SAFE:
            self.query_one("#prompt", Static).update("[dim]Install hidden in SAFE. Press m for GUIDED/ALL.[/]")
            return
        if self.mode == Mode.ALL and e.dangerous_install:
            self._armed_install = e
            self.query_one("#prompt", Static).update(
                f"[bold red]Install armed:[/] {' '.join(e.install_cmd)}\nPress y to confirm, n to cancel."
            )
            return
        self._run_install(e)

    def action_confirm(self) -> None:
        if not self._armed_install:
            return
        e = self._armed_install
        self._armed_install = None
        self.query_one("#prompt", Static).update("")
        self._run_install(e)

    def action_cancel(self) -> None:
        if not self._armed_install:
            return
        self._armed_install = None
        self.query_one("#prompt", Static).update("[dim]Cancelled.[/]")

    def _run_install(self, e: AppEntry) -> None:
        try:
            p = subprocess.run(e.install_cmd, text=True, capture_output=True)
            self._last_log = (p.stdout or "") + ("\n" + p.stderr if p.stderr else "")
        except Exception as ex:
            self._last_log = f"Install failed: {ex}"
        self.refresh_ui()

    def _exec_replace(self, cmd: list[str]) -> None:
        os.execvp(cmd[0], cmd)
