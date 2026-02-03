Perfect. To close this out cleanly and give you a **natural pause point**, here’s the **final condensed deliverable** you can copy-paste directly into a PR description or a tracking issue. It reflects **everything we designed**, with nothing hand-wavy left.

I’ll give you:

1. **One PR overview (what this PR achieves)**
2. **Incremental commit plan (ordered, reviewable)**
3. **Final PR checklist (GitHub-style task list)**
4. **Clear pause point criteria (“we’re done when…”)**

No new ideas here — just crystallization.

---

# PR Overview (top of PR description)

**Title**
**Studio cockpit: STATION readiness, preflight/check, streaming logs, single-source interaction**

**Summary**
This PR upgrades `studio-operator` into a first-run-friendly **creative OS cockpit**:

* One-command onboarding (`make onboard`)
* Shared readiness model (`A / S / I / F / R`)
* Deterministic “next action” everywhere (CLI + TUI)
* SAFE / GUIDED / ALL modes that are truthful and obvious
* Streaming in-TUI execution with logs + recovery shortcuts
* Toasts for every no-op, failure, and milestone
* **Single source of truth** for key bindings, legend, and help

The result: a new user can always answer

> *“What state am I in, what should I do next, and how do I recover?”*

without reading code or guessing modes.

---

# Incremental Commit Plan (single PR, linear history)

## Commit 1 — Docs + Make targets

**Files**

* `Makefile`
* `README.md`
* `docs/first_run.md`
* `docs/capabilities.md`
* `docs/modes.md`

**What lands**

* `make onboard` → `wub preflight --auto`
* `make check`
* README points to First Run
* Modes + capabilities documented

---

## Commit 2 — Core state & parsing primitives

**New files**

* `StudioStateTypes.swift`
* `RunLocator.swift`
* `ReceiptSignal.swift`
* `ArtifactIndexParser.swift`

**What lands**

* Gate model (A/S/I/F/R)
* Tolerant receipt parsing
* Tolerant artifact index parsing
* Latest-run discovery without brittle filenames

*No UI wiring yet.*

---

## Commit 3 — StudioStateEvaluator + STATION bar rendering

**New files**

* `StudioStateEvaluator.swift`
* `StudioStateRendering.swift`

**What lands**

* Pure evaluator → snapshot (gates + recommended next)
* Deterministic next-action policy
* Compact STATION bar renderer:

  ```
  STATION  A▣  S▢  I▣  F×(3)  R▢    next: wub assets export-all …
  ```

---

## Commit 4 — CLI: `wub check` + `wub preflight`

**New files**

* `CheckCommand.swift`
* `PreflightCommand.swift`

**Edits**

* `WubCli.swift`

**What lands**

* `wub check` (read-only truth, exit codes)
* `wub preflight` (gate, auto-safe steps, no doctor)
* CLI and TUI now share evaluator

---

## Commit 5 — Operator Shell modes cleanup (SAFE / GUIDED / ALL)

**Edits**

* `OperatorShellCommand.swift`

**What lands**

* Remove misleading `all=ON`
* Explicit modes:

  * SAFE (locked)
  * GUIDED (curated)
  * ALL (full)
* `a` key becomes honest (no-op explained in SAFE)
* GUIDED uses `isGuided` flag (no title matching bugs)

---

## Commit 6 — Toast system

**New**

* `ToastManager.swift`

**Edits**

* `OperatorShellCommand.swift`

**What lands**

* Priority + throttled toasts
* Every no-op, failure, success explained
* Milestone language (“Artifacts complete”, “Studio ready”)

---

## Commit 7 — STATION bar integrated into Operator Shell

**Edits**

* `OperatorShellCommand.swift`

**What lands**

* Header driven by evaluator snapshot
* SPACE runs deterministic “next”
* Hidden actions explain how to reveal
* Gate transitions trigger milestone toasts

---

## Commit 8 — Log pane + recovery shortcuts

**New**

* `LogBuffer.swift` (or inline struct)

**Edits**

* `OperatorShellCommand.swift`

**What lands**

* In-TUI logs pane (`l`, `ESC`, `0`)
* Recovery keys:

  * `o` open run
  * `f` open failures
  * `r` open receipt
* Logs persist across actions

---

## Commit 9 — Non-blocking execution + polling input

**New**

* `InputDecoder.swift` (select() + ESC parsing)
* `StreamingProcess.swift`

**Edits**

* `OperatorShellCommand.swift`

**What lands**

* No more “Press Enter to return…”
* Logs stream live
* UI stays visible while running
* Optional `c cancel`

---

## Commit 10 — Single source of truth for interaction

**New**

* `InteractionTypes.swift`
* `ActionCatalog.swift`
* `ActionRouter.swift`
* `LegendRenderer.swift`
* `HelpOverlayRenderer.swift`

**Edits**

* `OperatorShellCommand.swift`
* `InputDecoder.swift`

**What lands**

* Actions (not keys) are primary
* Bindings, legend, and help generated from same catalog
* Context-aware routing (SAFE/GUIDED/logs/confirming)
* No drift between help and behavior

---

## Commit 11 — Onboarding polish

**New**

* `AnchorsSelectCommand.swift` (if missing)

**Edits**

* Docs + preflight integration

**What lands**

* `wub anchors select`
* Anchors surfaced clearly in header
* `make onboard` fully guided end-to-end

---

# Final PR Checklist (paste into PR)

```markdown
## First-run experience
- [ ] `make onboard` works on a clean machine
- [ ] `wub preflight` ends in CLEARED or BLOCKED with exact next steps
- [ ] `wub check` shows A/S/I/F/R + recommended next

## Operator Shell cockpit
- [ ] STATION bar always visible (A/S/I/F/R)
- [ ] SAFE / GUIDED / ALL are explicit and truthful
- [ ] SPACE runs deterministic next action
- [ ] Hidden actions explain how to reveal
- [ ] Milestone toasts fire on gate transitions

## Execution & recovery
- [ ] Commands run without leaving the TUI
- [ ] Logs stream live
- [ ] `o / f / r` open run, failures, receipt
- [ ] Failures are actionable without guessing

## Interaction hygiene
- [ ] Single source of truth for actions/bindings/help
- [ ] Legend never lies
- [ ] Help overlay matches actual behavior

## Docs
- [ ] README points to First Run
- [ ] First Run explains STATION bar + modes
- [ ] Capabilities doc maps commands → intent
```

---

# Clean Pause Point (you can stop here)

You’re **done** when:

* A first-time user can run `make onboard` and never ask:
  *“What do I do now?”*
* No key ever does “nothing” without explanation
* No doc contradicts the UI
* No UI contradicts actual behavior
* Adding a new action requires **one change** (ActionCatalog)

At that point, the repo is in a **healthy, extensible state** — and this is an excellent place to pause before adding new capabilities.

If/when you want to continue later, the next natural layer would be:

* persistence of per-studio profiles,
* or visualizing longitudinal readiness history,
* or exposing the evaluator over a socket/UI.

But for now: this is a strong, clean stopping point.
