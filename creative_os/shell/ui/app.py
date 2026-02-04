from __future__ import annotations

from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Header, Footer, Static, ListView, ListItem
from textual.binding import Binding

from ..types import Mode
from ..adapter import OperatorShellAdapter
from .theme import theme_for

class ActionItem(ListItem):
    def __init__(self, label: str, action_id: str, dangerous: bool):
        super().__init__(Static(label))
        self.action_id = action_id
        self.dangerous = dangerous

class OperatorShellApp(App):
    BINDINGS = [
        Binding("m", "toggle_mode", "Mode"),
        Binding("p", "plan_selected", "Plan"),
        Binding("enter", "apply_selected", "Apply"),
        Binding("r", "refresh", "Refresh"),
        Binding("space", "apply_recommended", "Next"),
        Binding("q", "quit", "Quit"),
        Binding("y", "confirm", "Confirm", show=False),
        Binding("n", "cancel", "Cancel", show=False),
        Binding("1", "apply_n(1)", "1"),
        Binding("2", "apply_n(2)", "2"),
        Binding("3", "apply_n(3)", "3"),
        Binding("4", "apply_n(4)", "4"),
        Binding("5", "apply_n(5)", "5"),
        Binding("6", "apply_n(6)", "6"),
        Binding("7", "apply_n(7)", "7"),
        Binding("8", "apply_n(8)", "8"),
        Binding("9", "apply_n(9)", "9"),
    ]

    def __init__(self, adapter: OperatorShellAdapter):
        super().__init__()
        self.adapter = adapter
        self.mode: Mode = Mode.SAFE
        self._actions = []
        self._recommended = None
        self._armed_action_id = None
        self._armed_action_label = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)
        with Horizontal():
            with Vertical(id="left"):
                yield Static("", id="mode_bar")
                yield ListView(id="actions")
            with Vertical(id="right"):
                yield Static("", id="state")
                yield Static("", id="log")
                yield Static("", id="prompt")
        yield Footer()

    def on_mount(self) -> None:
        self.refresh_ui()

    def refresh_ui(self) -> None:
        state = self.adapter.get_state()
        self._recommended = state.recommended_action_id

        t = theme_for(self.mode)
        next_id = state.recommended_action_id or "—"
        next_reason = state.stats.get("next_reason", "")
        self.query_one("#mode_bar", Static).update(
            f"[{self.adapter.name.upper()}] {t.badge}  [bold]Next:[/] {next_id}  [dim]{next_reason}[/]  (space runs next)"
        )

        self.query_one("#state", Static).update(state.stats.get("status_output", "").strip() or "(no status)")

        lv = self.query_one("#actions", ListView)
        lv.clear()
        self._actions = self.adapter.list_actions(self.mode)
        for a in self._actions:
            key = a.key or ""
            danger = " [bold red]⚠[/]" if a.dangerous else ""
            lv.append(ActionItem(f"{key}. {a.label}{danger}", a.id, a.dangerous))

        self.query_one("#log", Static).update(self.adapter.tail_logs())
        self.query_one("#prompt", Static).update("")
        self._armed_action_id = None
        self._armed_action_label = None

    def action_toggle_mode(self) -> None:
        self.mode = Mode.GUIDED if self.mode == Mode.SAFE else (Mode.ALL if self.mode == Mode.GUIDED else Mode.SAFE)
        self.refresh_ui()

    def _selected_item(self):
        lv = self.query_one("#actions", ListView)
        item = lv.highlighted_child
        return item if isinstance(item, ActionItem) else None

    def _arm_if_dangerous(self, action_id: str, label: str, dangerous: bool) -> bool:
        if self.mode == Mode.ALL and dangerous:
            self._armed_action_id = action_id
            self._armed_action_label = label
            self.query_one("#prompt", Static).update(
                f"[bold red]Dangerous action armed:[/] {label}\nPress [bold]y[/] to confirm, [bold]n[/] to cancel."
            )
            return True
        return False

    def action_confirm(self) -> None:
        if not self._armed_action_id:
            return
        aid = self._armed_action_id
        label = self._armed_action_label or aid
        self.query_one("#prompt", Static).update("")
        self._armed_action_id = None
        self._armed_action_label = None
        receipt = self.adapter.apply(aid)
        lines = [f"{label} -> {receipt.status}"] + (["Artifacts:"] + receipt.artifacts if receipt.artifacts else [])
        lines += ["", self.adapter.tail_logs(receipt.id)]
        self.query_one("#log", Static).update("\n".join(lines))
        self.refresh_ui()

    def action_cancel(self) -> None:
        if not self._armed_action_id:
            return
        self._armed_action_id = None
        self._armed_action_label = None
        self.query_one("#prompt", Static).update("[dim]Cancelled.[/]")

    def action_plan_selected(self) -> None:
        item = self._selected_item()
        if not item:
            return
        plan = self.adapter.plan(item.action_id)
        self.query_one("#log", Static).update("\n".join([plan.summary] + plan.diff[:200]))

    def action_apply_selected(self) -> None:
        item = self._selected_item()
        if not item:
            return
        if self._arm_if_dangerous(item.action_id, item.action_id, item.dangerous):
            return
        receipt = self.adapter.apply(item.action_id)
        lines = [receipt.summary] + (["Artifacts:"] + receipt.artifacts if receipt.artifacts else [])
        lines += ["", self.adapter.tail_logs(receipt.id)]
        self.query_one("#log", Static).update("\n".join(lines))
        self.refresh_ui()

    def action_apply_recommended(self) -> None:
        if not self._recommended:
            self.refresh_ui()
            return
        rec = next((a for a in self._actions if a.id == self._recommended), None)
        if rec and self._arm_if_dangerous(rec.id, rec.label, rec.dangerous):
            return
        receipt = self.adapter.apply(self._recommended)
        self.query_one("#log", Static).update(f"{receipt.summary}\n\n{self.adapter.tail_logs(receipt.id)}")
        self.refresh_ui()

    def action_refresh(self) -> None:
        self.refresh_ui()

    def action_apply_n(self, n: int) -> None:
        for a in self._actions:
            if a.key == str(n):
                if self._arm_if_dangerous(a.id, a.label, a.dangerous):
                    return
                receipt = self.adapter.apply(a.id)
                self.query_one("#log", Static).update(f"{receipt.summary}\n\n{self.adapter.tail_logs(receipt.id)}")
                self.refresh_ui()
                return
