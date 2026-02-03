Below is a **single PR plan** (one branch / one PR) with **incremental commits** you can land in order. Each commit is reviewable, keeps the shell working, and cumulatively delivers *all* the key features we designed:

* **First-time “one command” onboarding** (`make onboard`)
* **New CLI primitives**: `wub check` + `wub preflight` (no `doctor`)
* **Readiness evaluator** shared across CLI + TUI
* **Compact STATION readiness bar (A/S/I/F/R)** with deterministic “next”
* **SAFE / GUIDED / ALL** mode model + clear View behavior (fixes confusing `all=ON`)
* **Toasts** with throttling + priority
* **In-TUI log pane** + polling refresh + (optional) cancel + recovery hotkeys (`o/f/r`)
* **Single source of truth** for interaction: bindings + legend + help all come from one catalog
* **Docs + Makefile** upgrades (First Run / Capabilities / Modes)

I’m listing **file paths**, what changes in each commit, and **acceptance checks** so nothing gets overlooked.

---

# PR: “First-run cockpit: STATION bar, preflight/check, logs, single-source interaction”

## Commit 1 — Docs + Make targets (no code behavior change)

**Goal:** give first-time users the right entrypoint immediately.

### Files

* `Makefile`
* `docs/first_run.md` (new)
* `docs/capabilities.md` (new)
* `docs/modes.md` (new) *(or embed Modes section into first_run)*
* `README.md` (update links + “First Run” section)

### Changes

* Add Make targets:

  * `make onboard` → build swift-cli → `wub preflight --auto`
  * `make check` → build swift-cli → `wub check`
  * keep `make studio` unchanged
* Update README to:

  * **First Run** → `make onboard`
  * **Operator Shell** → `make studio`
  * **Capabilities** → docs link
  * **Modes** → docs link

### Acceptance

* `make studio` still works as before.
* README’s first section points to `make onboard`.

---

## Commit 2 — Introduce shared types + utilities skeleton (no UI wiring yet)

**Goal:** lay the foundation for evaluator + rendering without touching OperatorShell behavior.

### Files (new)

* `tools/automation/swift-cli/Sources/StudioCore/StudioStateTypes.swift`
* `tools/automation/swift-cli/Sources/StudioCore/RunLocator.swift`
* `tools/automation/swift-cli/Sources/StudioCore/ReceiptSignal.swift`
* `tools/automation/swift-cli/Sources/StudioCore/ArtifactIndexParser.swift`

### Contents

* `Gate`, `GateStatus`, `GateResult`, `RecommendedNext`, `StudioStateSnapshot`
* `RunLocator` (scan latest N runs; match by substrings)
* `ReceiptSignal` tolerant parser + staleness helper
* `ArtifactIndexParser` tolerant missing/placeholder counter

### Acceptance

* swift-cli builds.
* No behavior changes yet.

---

## Commit 3 — Add `StudioStateEvaluator` (pure) + bar rendering helpers

**Goal:** produce a stable snapshot: gates + recommended next + header fields.

### Files (new)

* `tools/automation/swift-cli/Sources/StudioCore/StudioStateEvaluator.swift`
* `tools/automation/swift-cli/Sources/StudioCore/StudioStateRendering.swift`

### Changes

* Implement `StudioStateEvaluator.evaluate(...)`:

  * A: anchors configured?
  * S: sweep receipt signal (stale warn)
  * I/F: artifact index + missing/placeholder counts
  * R: ready verify receipt signal (stale warn)
  * deterministic recommended next (first FAIL gate, else actionable stale/pending)
* Implement `StationBarRender.renderLine1(...)` producing:

  * `STATION     A▣  S▢  I▣  F×(3)  R▢    next: <cmd>   [SPACE]`

### Acceptance

* Add a tiny unit-ish harness (optional) or local test by calling evaluator from a scratch command.
* No OperatorShell changes yet.

---

## Commit 4 — Add CLI commands: `wub check` and `wub preflight`

**Goal:** make onboarding contract real before changing TUI.

### Files

* `tools/automation/swift-cli/Sources/StudioCore/WubCli.swift` *(register new commands; your CLI is ArgumentParser-based)*
* `tools/automation/swift-cli/Sources/StudioCore/CheckCommand.swift` (new)
* `tools/automation/swift-cli/Sources/StudioCore/PreflightCommand.swift` (new)

### Changes

* `wub check`:

  * prints readiness bar + blockers/warnings + recommended next
  * exit 0 cleared, 2 blocked, 1 internal
* `wub preflight`:

  * runs `check`
  * if blocked: prints blockers + next steps + exits 3
  * `--auto`: runs safe prerequisites (index build and sweep if needed/stale)
  * `--allow-danger`: allows prompts for export-all / drift fix etc. (you can limit to export-all initially)
* **No doctor alias**.

### Acceptance

* `make check` works.
* `make onboard` works (even if it blocks, it explains why + next).

---

## Commit 5 — Operator Shell: replace `all=ON` with explicit SAFE/GUIDED/ALL and View truth

**Goal:** remove the biggest confusion *without* changing execution model yet.

### Files

* `tools/automation/swift-cli/Sources/StudioCore/OperatorShellCommand.swift`

### Changes

* Introduce derived `ShellMode = SAFE | GUIDED | ALL`

  * SAFE = studioMode on
  * GUIDED/ALL = studioMode off + showAll false/true
* UI text changes:

  * remove `all=ON/OFF`
  * show `mode: SAFE|GUIDED|ALL (vis/total)` and “view locked” in SAFE
* Fix “TOP list string-match brittleness”:

  * add `isGuided` (or `tier`) to menu items
  * GUIDED view uses that flag instead of title matching (prevents rename bugs)
* Ensure recommended action visibility messaging:

  * if hidden in SAFE or not shown in GUIDED, surface a note line

### Acceptance

* `a` in SAFE no longer “pretends” to work; UI says view locked.
* GUIDED/ALL toggle is clear and stable across renames.

---

## Commit 6 — Toast system: `ToastManager` + toasts wired to real friction points

**Goal:** every no-op and failure becomes actionable.

### Files (new)

* `tools/automation/swift-cli/Sources/StudioCore/ToastManager.swift`

### Files (edit)

* `OperatorShellCommand.swift`

### Changes

* Add `ToastManager` with:

  * priority (blocked > success > info)
  * throttling (per-key TTL)
  * expiry
* Render toast line just above key legend.
* Wire toasts to:

  * `a` in SAFE → “View is locked in SAFE — press s…”
  * mode toggles → “Safe mode — risky hidden”, “Guided…”, “All actions…”
  * SPACE with no next → “No pending actions — studio is ready”
  * hidden recommended action → “press s” / “press a”
  * run success/fail → “Completed successfully” / “see runs/<id>”

### Acceptance

* No silent no-ops.
* Toasts don’t spam (throttle works).

---

## Commit 7 — STATION readiness bar + evaluator-driven “next” inside Operator Shell

**Goal:** cockpit header becomes self-explanatory; SPACE runs deterministic next.

### Files

* `OperatorShellCommand.swift`
* (optional) `HeaderComposer.swift` (new) if you want to keep rendering clean

### Changes

* Instantiate evaluator in shell
* Re-evaluate on cadence:

  * idle 0.5s
  * running 1.0s
  * immediate after run completion
* Render header lines (exact spacing + truncation rules you approved):

  1. STATION bar + next
  2. mode/view line
  3. Anchors + Station + Last (adaptive truncation)
  4. optional note/confirm
* SPACE behavior uses `snapshot.recommended`:

  * hidden → toast instructing how to reveal
  * else run action
* Gate transition milestone toasts:

  * Anchors configured, Sweep passed, Index built, Artifacts complete, Studio ready

### Acceptance

* Header always shows A/S/I/F/R and “next”.
* After successful export-all, `F×(n)` transitions to `F▣` and triggers toast “Artifacts complete”.

---

## Commit 8 — Log pane (view), scroll, recovery hotkeys `o/f/r`, still using legacy runner

**Goal:** immediate recovery UX even before streaming.

### Files

* `OperatorShellCommand.swift`
* (new) `LogBuffer.swift` and small runner state structs OR keep local in shell for now

### Changes

* Add `showLogs` flag and render log pane view
* Add keys:

  * `l` toggle logs, `ESC` back, `0` bottom
  * `o` open run dir, `f` open failures, `r` open receipt
* Add helper `openInFinder(path)` (macOS `open`)
* After any run, set `showLogs = true` and append a summary into the log buffer (even if process output still goes to stdout for now)

### Acceptance

* After a failure, user can hit `f` and recover quickly.
* Logs view does not break normal menu use.

---

## Commit 9 — Non-blocking execution: streaming runner + polling input (no more “Press Enter to return…”)

**Goal:** keep cockpit visible while commands run; logs stream; UI stays live.

### Files (new)

* `tools/automation/swift-cli/Sources/StudioCore/StreamingProcess.swift` *(Process + Pipe + readability handler + line splitting)*
* `tools/automation/swift-cli/Sources/StudioCore/InputDecoder.swift` *(select()-based polling returning KeyEvent)*

### Files (edit)

* `OperatorShellCommand.swift`

### Changes

* Replace blocking execution path with runner state machine:

  * `.confirming` (danger prompt in-place)
  * `.running` (streams logs)
  * `.finished`
* Add polling input:

  * `readKeyEvent(timeoutMs:)` using `select()` and ESC-sequence parsing
  * `.none` on timeout to allow redraw while streaming
* Remove cooked-mode confirmation and the “Press Enter to return…” pause.
* Optionally add `c cancel` (SIGINT) when running.

### Acceptance

* Start export-all: logs stream in pane, STATION bar remains visible.
* On completion, evaluator refreshes and bar updates immediately.
* No blocking prompts outside TUI.

---

## Commit 10 — Single source of truth for interaction: ActionCatalog → router → legend + help overlay

**Goal:** eliminate drift: bindings, legend, and help always match actual behavior.

### Files (new)

* `tools/automation/swift-cli/Sources/StudioCore/InteractionTypes.swift`

  * `KeyEvent`, `UserAction`, `ShellContext`, `KeyGroup`
* `tools/automation/swift-cli/Sources/StudioCore/ActionCatalog.swift`

  * list of `ActionSpec` entries: bindings + short + help + visibility + dropPriority
* `tools/automation/swift-cli/Sources/StudioCore/ActionRouter.swift`

  * resolves `KeyEvent` → `UserAction` given context
* `tools/automation/swift-cli/Sources/StudioCore/LegendRenderer.swift`

  * renders one-line legend from catalog (width fitted)
* `tools/automation/swift-cli/Sources/StudioCore/HelpOverlayRenderer.swift`

  * renders `?` overlay from catalog (box + fallbacks)

### Files (edit)

* `OperatorShellCommand.swift`
* `InputDecoder.swift` (if needed to return `KeyEvent`)

### Changes

* Replace `Key` enum / bespoke legend strings with:

  * `KeyEvent` from input decoder
  * `UserAction` from router
* Switch loop becomes: `switch action { … }`
* Legend line generated from catalog (never lies)
* Help overlay generated from catalog (never lies)
* Confirmation state uses same router (y/n only visible when confirming)

### Acceptance

* Change a binding in one place (ActionCatalog) and both legend + help update automatically.
* SAFE/GUIDED/ALL visibility is encoded once (no duplicated if/else logic in multiple renderers).

---

## Commit 11 — Finish onboarding polish: anchors select + preflight hooks + docs cross-links

**Goal:** close the loop for first-time users.

### Files

* Add command if missing: `tools/automation/swift-cli/Sources/StudioCore/AnchorsSelectCommand.swift`
* Update docs references to new commands:

  * `docs/first_run.md` includes `wub check`, `wub preflight`, and STATION bar reading guide

### Changes

* `wub anchors select` interactive selector:

  * scan likely anchor dirs
  * write to `notes/LOCAL_CONFIG.json`
* Ensure `wub preflight --auto` can call it or instruct it when anchors missing.
* Ensure Operator Shell header always shows anchors pack name/path (truncated).

### Acceptance

* Clean machine: user can run `make onboard` and be guided to set anchors and proceed.

---

# “Done” checklist for the PR (nothing left behind)

### First-time user contract

* `make onboard` exists and runs `wub preflight --auto`
* `wub preflight` ends in **CLEARED** or **BLOCKED with exact next steps**
* `wub check` gives state truth + recommended next

### Operator Shell cockpit

* STATION bar: A/S/I/F/R always visible
* Mode model: SAFE / GUIDED / ALL is explicit
* `a` is never misleading in SAFE (locked + toast)
* `SPACE` always runs deterministic “next” or explains why it can’t
* Toasts explain every no-op and failure, throttled and prioritized
* Logs pane exists, streams during runs, never drops out of TUI
* Recovery hotkeys: `o/f/r` open run/fail/receipt paths quickly

### Interaction hygiene

* Single source of truth for:

  * bindings
  * legend tokens
  * help text
  * visibility by context

### Docs hygiene

* README points to `make onboard` first
* First Run doc teaches STATION bar + modes + recovery pattern
* Capabilities doc maps commands to “what it enables”
* Modes doc clarifies SAFE/GUIDED/ALL

---

# Suggested PR title + description

**Title:** `Studio cockpit: STATION readiness, preflight/check, streaming logs, single-source interaction`

**Description bullets:**

* One-command onboarding (`make onboard`)
* New CLI: `wub check`, `wub preflight`
* Operator Shell: STATION readiness bar (A/S/I/F/R), SAFE/GUIDED/ALL modes, deterministic next
* Streaming in-TUI runner + log pane + recovery hotkeys
* Toasts + single-source-of-truth interaction catalog
* Docs updated: First Run / Capabilities / Modes

---

If you want, I can also format this as a PR checklist (GitHub markdown task list) you can paste into the PR description, so review stays crisp and nothing slips.
