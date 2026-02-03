
Below is an updated, consolidated plan that incorporates **everything** from your earlier “first-time user upgrade” blueprint **plus** a clean fix for the confusing **`all=ON (a)`** behavior, reframed as an intentional **View** system that matches how the Operator Shell actually works today.

I’m going to keep this practical: concrete behaviors, concrete file touch points, and an implementation order that’s efficient.

---

# North Star

A first-time user should be able to run:

```bash
make onboard
```

…and reliably end in exactly one of two states:

* **CLEARED**: “Studio is ready. Voice + automation are safe to use.”
* **BLOCKED**: “Here are the blockers, the next command(s), and where to look (runs/<id>/…).”

Everything else (docs, Make targets, TUI modes) should support this contract.

---

# System contract to document and enforce

## Readiness pipeline

This is the canonical “what done means”:

1. **Anchors pack configured**
2. **Sweep passes** (modal/perception sanity)
3. **Index exists**
4. **Artifacts complete** (no missing / placeholder)
5. **Ready verify passes**

This aligns with the existing wizard intent and the Operator Shell’s “recommended next action” logic.

## Mode + View contract (this is the key update)

Right now you effectively have *two orthogonal toggles* that don’t compose clearly:

* **Studio Mode**: safe-only by hiding `danger` items
* **all=ON/OFF**: actually TOP-vs-ALL view, and it’s ignored in Studio Mode

We will make this explicit and user-facing:

### New conceptual model (single mental model)

There are **three user-facing modes** (even if internally you keep two toggles):

1. **SAFE**

   * Studio Mode ON
   * Only non-danger items
   * View is effectively locked

2. **GUIDED**

   * Studio Mode OFF
   * Curated essential set (includes some dangerous items)
   * This is what “TOP” was trying to be

3. **ALL**

   * Studio Mode OFF
   * Full surface area

This eliminates “why does `a` not do anything?” and “what does all=ON enable?”

---

# Upgrade plan, step-by-step

## 1) CLI: Add `check` + `preflight` (no `doctor`, no alias)

### 1.1 `wub check` (read-only truth)

**Purpose:** “What’s my state right now?” (no side effects)

Minimum outputs:

* Anchors pack configured? path
* Index present?
* Pending artifacts: missing vs placeholder
* Drift status (if applicable)
* Station signal (if available)
* Recommended next action (single best next step)

Exit codes:

* `0` = no blockers
* `2` = blockers exist (action required)
* `1` = internal error

### 1.2 `wub preflight` (readiness gate)

**Purpose:** “Can I begin operating now?”

Behavior:

* Runs `check`
* If blockers: prints blockers + exact next command(s) + where receipts/logs are, then exits nonzero
* Optional flags:

  * `--auto` runs *safe* prerequisites (e.g., build index if missing)
  * `--allow-danger` allows prompts to run dangerous remediation (export-all, drift fix, repair)

Exit codes:

* `0` = CLEARED
* `3` = BLOCKED (actionable)
* `1` = internal error

**Design rule:** preflight is the “gate”; check is the “meter.”

---

## 2) Make targets: encode the one-command promise

Keep `make studio` unchanged (power users rely on it).

Add:

### 2.1 `make onboard`

* Build swift-cli
* Run: `wub preflight --auto`
* If blocked: prints next steps clearly (preflight output should already do this)

### 2.2 `make check`

* Build swift-cli
* Run: `wub check`

### 2.3 optional: `make preflight`

* `wub preflight` (without auto) for operators who want strict gating

---

## 3) Docs: restructure into “First Run” + “Capabilities” + “Modes”

### 3.1 `docs/first_run.md`

Must be the authoritative path.

Include:

* One-liner: `make onboard`
* What “done” means (the readiness pipeline)
* Anchors pack explained plainly (what it is, why it’s required)
* Where receipts/logs live (`runs/<id>/…`)
* Recovery by symptom:

  * “No anchors pack configured”
  * “Sweep failed due to modals”
  * “Artifacts missing → export-all”
  * “Drift detected → drift plan → drift fix”
  * “Ready verify fails → repair”

### 3.2 `docs/capabilities.md`

Group by intent, not subcommands:

* Perception & Safety: sweep
* Provisioning: assets export-*
* Bookkeeping: index build/status
* Divergence: drift check/plan/fix
* Readiness: ready verify/certify
* Voice runtime: vrl validate/run

Each entry:

* When to run
* Prereqs
* Outputs (receipt/report names + where to find)
* Recovery steps

### 3.3 `docs/modes.md` (or a Modes section in First Run)

Explain the *new* model:

* **SAFE**: hides risky steps (exports/fix/repair/certify)
* **GUIDED**: curated operational steps incl. some risky
* **ALL**: full surface area

And include the one-liner:

> “If you can’t find Export ALL, you’re in SAFE.”

### 3.4 Root README refocus

Top of README should be:

* **First Run** → `make onboard` → link first_run.md
* **Operator Shell** → `make studio` → link operator shell doc
* **Capabilities** → link capabilities.md
* **Modes** → link modes.md (or anchor section)

---

## 4) TUI: make it self-teaching and un-trappable

This is where first-time confusion is actually felt.

### 4.1 Replace `all=ON/OFF` with `view=GUIDED/ALL` and make SAFE explicit

**Goal:** UI must reflect truth:

* In Studio Mode, the “view” toggle is a no-op → so don’t present it as if it works.

#### What the header should show

* If Studio Mode ON:

  * `mode: SAFE (hiding risky actions) — press s to reveal`
  * `view: locked`
* If Studio Mode OFF:

  * `mode: GUIDED` or `mode: ALL`
  * `view: GUIDED|ALL (press a)`

#### Add counts (this is huge)

Show: `visible/total` (and optionally safe count)

* `mode: SAFE  (9/20 visible)`
* `mode: GUIDED (12/20 visible)`
* `mode: ALL   (20/20 visible)`

This instantly answers “what changed?”

### 4.2 Fix the TOP/GUIDED selection so it never breaks on rename

Right now “TOP” is implemented as string-title matching. That’s brittle and already caused a bug: the “DubSweeper” label mismatch means sweep can disappear.

**Fix:** add an explicit field on MenuItem:

* `tier: .guided / .all` (or `isGuided: Bool`)
* Then GUIDED view is `items.filter { $0.isGuided }`

This makes refactors safe.

### 4.3 Make “Recommended next action” always actionable even if not visible

You already compute and display a recommended action and allow “Space” to run it. Keep that, but add:

* If recommended action is not in current visible list:

  * Show: `recommended: <x> (press a to reveal)` **or**
  * Pin a synthetic first menu item: `▶ Run recommended action`

This prevents the view filter from ever becoming a trap.

### 4.4 Studio Mode banner + hidden-danger hint

This remains the single highest leverage usability fix:

* Always show:

  * `SAFE hides risky actions (exports/fix/repair/certify)`
* If the recommended next action is dangerous:

  * `Recommended action is risky and hidden in SAFE — press s`

### 4.5 Add an “Explain” panel per command (capability framing)

When an item is selected, show:

* What it enables
* Prereqs
* Outputs (receipt/report paths)
* Risks
* Recovery steps (exact next command)

Implementation: add metadata on MenuItem:

* `why: String`
* `prereqs: [String]`
* `outputs: [String]`
* `risk: String?`
* `recovery: [String]`

This reduces dependence on docs and makes the shell teach itself.

### 4.6 Failure UX: always give next step + where to look

On non-zero command exit:

* Print:

  * FAILED: <command>
  * Receipt/log path: runs/<id>/...
  * Next recommended action: <computed>
* Provide one-key shortcut:

  * open failures folder / last run folder

This turns failure into a guided next action.

### 4.7 Add “Preflight (First Run)” as a first-class menu entry

If `firstRunCompleted` is false:

* Show `Preflight (First Run)` at the top
* Runs `wub preflight --auto`
* If it requires dangerous steps (export-all etc.):

  * prompt explicitly
  * or instruct “press s to proceed” and highlight the next item

This makes the UI itself the onboarding.

---

## 5) Anchors pack: make it unmistakable and easy to set

### 5.1 Always show anchors pack in the header

`Anchors: <name> (<path>)` or `Anchors: NOT SET`

### 5.2 Add “Select Anchors Pack…” menu entry

* scans known directories
* shows candidates
* writes `notes/LOCAL_CONFIG.json`

### 5.3 Preflight hard-block if anchors pack absent

Preflight output should be explicit:

* Blocker: Anchors pack not configured
* Fix: run `wub ui --anchors-pack …` **or** `wub anchors select` (recommended)

---

## 6) Unify logic behind a single “Studio State Evaluator”

This is the “efficient swoop” engineering move that prevents divergence between:

* wizard behavior
* recommended next action
* check/preflight
* TUI header state

Create a shared evaluator:

### `StudioState.evaluate()`

Returns:

* `modeledReadiness`: CLEARED / BLOCKED
* `blockers[]` (typed)
* `warnings[]`
* `recommendedAction` (a MenuItem or a command string)
* `paths` (last drift report, last station status, last failures dir)
* `counts` (pending missing, placeholder)

Then:

* `wub check` prints it
* `wub preflight` gates on it
* TUI renders it
* wizard uses it

---

# Implementation order (efficient + low risk)

## PR1 — UX + Docs + Make targets (big win without new core logic)

1. Makefile: add `onboard`, `check`, maybe `preflight`
2. Docs: first_run.md, capabilities.md, modes.md; update root README links
3. TUI:

   * Rename `all` → `view` with truthful behavior
   * SAFE/GUIDED/ALL labeling + counts
   * Fix “DubSweeper vs Sweep” mismatch immediately
   * Replace title-based TOP filter with `isGuided`
   * Hidden recommended-action hints
   * Studio banner explaining what’s hidden

This alone will massively reduce confusion even before `check/preflight` exists.

## PR2 — New commands + unified evaluator

1. Add evaluator
2. Implement `wub check`
3. Implement `wub preflight`
4. Wire `make onboard` to `wub preflight --auto`
5. Add TUI “Preflight (First Run)” menu entry that runs it

---

# What first-time users will see after these changes

## `make onboard`

* If CLEARED:

  * “Preflight: CLEARED”
  * “You can now: make studio” + quick next steps
* If BLOCKED:

  * “Preflight: BLOCKED”
  * bullet blockers
  * exact next command(s)
  * paths to receipts/logs

## Operator Shell header

* It will always be obvious whether they’re in SAFE/GUIDED/ALL
* It will be obvious whether view is locked
* It will be obvious how many commands are hidden and why
* If they’re stuck, “recommended next action” will tell them exactly what to do, and if it’s hidden, it will tell them how to reveal it

---

# The specific `all=ON (a)` cleanup: final spec

### Replace:

* `all=ON/OFF (a)`

### With:

* In SAFE: `mode: SAFE (x/y)  view: locked`
* In non-SAFE:

  * `mode: GUIDED (x/y)  view: GUIDED (a)`
  * `mode: ALL (x/y)     view: ALL (a)`

### Key behavior:

* `a` toggles GUIDED ⇄ ALL **only when Studio Mode is OFF**
* When Studio Mode is ON, `a` either:

  * does nothing and tells you “view locked in SAFE” **or**
  * automatically prompts “turn off SAFE?” (I prefer: do nothing + message)

### Data model:

* MenuItem has `isGuided`
* No string matching on titles

---

If you want one more “killer” improvement that ties it all together: have the Operator Shell show a compact **Readiness Bar** in the header (Anchors / Sweep / Index / Artifacts / Ready) with pass/fail markers. It becomes a persistent mental model and makes onboarding feel like a checklist rather than a mystery.

Perfect — the readiness bar can become the “instrument panel” that makes everything else (modes, view toggles, recommended actions, failures) feel obvious.

Below is a **concrete spec + implementation plan** for a compact readiness bar that works in the Operator Shell *and* becomes the backbone of `wub check` / `wub preflight` / `make onboard`.

---

# Readiness Bar: spec

## What it must do

* Show **the canonical pipeline** at a glance:

  1. Anchors
  2. Sweep
  3. Index
  4. Artifacts
  5. Ready
* Make it instantly clear:

  * **where you are blocked**
  * **what is already good**
  * **what hasn’t been evaluated yet**
* Provide a stable shared mental model across:

  * Operator Shell header
  * `wub check` output
  * `wub preflight` gating output
  * `docs/first_run.md`

## Compact rendering (TUI-friendly)

Use a single-line bar with 5 labeled segments:

```
READY:  A▣  S▣  I▣  F▣  R▣
```

Where each segment is one of:

* `▣` = PASS
* `▢` = PENDING / not run / unknown
* `×` = FAIL (blocking)
* `!` = WARN (non-blocking, but notable)

Example states:

**Fresh machine (anchors missing)**

```
READY:  A×  S▢  I▢  F▢  R▢   next: anchors select
```

**Anchors set, sweep failed**

```
READY:  A▣  S×  I▢  F▢  R▢   next: sweep
```

**Artifacts missing (common first-run)**

```
READY:  A▣  S▣  I▣  F×  R▢   next: assets export-all
```

**All good**

```
READY:  A▣  S▣  I▣  F▣  R▣   CLEARED
```

This is compact enough to fit into your existing header without becoming “UI noise.”

---

# What each segment means (strict contract)

## A — Anchors

PASS if:

* anchors pack configured in `notes/LOCAL_CONFIG.json` (or equivalent) AND exists on disk
  FAIL if missing / invalid path.

Also show the selected pack in header:

```
Anchors: <name> (<path>)
```

## S — Sweep (modal guard / perception)

PASS if:

* latest sweep receipt indicates no blocking modals (or passes signal checks)
  FAIL if:
* sweep shows blocking modal/dialog/permission issue
  PENDING if:
* no recent sweep receipt (or “unknown”)

**Important:** don’t require sweep every time; accept “last sweep within X minutes” as PASS, otherwise PENDING/WARN.

## I — Index

PASS if:

* artifact index exists and parses (e.g., `checksums/index/artifact_index.v1.json`)
  FAIL if:
* missing/unreadable
  PENDING if:
* not attempted (rare)

## F — Files/Artifacts

PASS if:

* no missing/placeholder artifacts (based on index)
  FAIL if:
* missing > 0 or placeholder > 0

Optionally: annotate counts:

```
F×(3)   # 3 missing/placeholder total
```

## R — Ready verify

PASS if:

* latest `ready verify` receipt is PASS
  FAIL if:
* latest is FAIL
  PENDING if:
* never run

This is your actual operational gate.

---

# Integrate with your Mode/View system

Once you have the readiness bar, **modes become secondary** and much easier to explain.

## Header layout proposal

Keep it to 3–4 lines:

1. **Readiness bar + next action**

```
READY: A▣ S▢ I▣ F× R▢   next: assets export-all  (press SPACE)
```

2. **Mode / View (your SAFE/GUIDED/ALL cleanup)**

```
mode: SAFE (9/20)   view: locked   (s: reveal) (a: disabled)
```

or

```
mode: GUIDED (12/20)  view: GUIDED (a)  (s: safe)
```

3. Anchors + station signal summary

```
Anchors: hvlien_v1   Station: detected   Last run: runs/2026-...
```

The readiness bar becomes the thing users trust. Mode/View just controls how they navigate.

---

# How the readiness bar drives onboarding

## `make onboard` experience

`wub preflight --auto` should print the same bar and then either:

### CLEARED

```
READY: A▣ S▣ I▣ F▣ R▣   CLEARED
Next: make studio
```

### BLOCKED (with exact blockers)

```
READY: A▣ S▣ I▣ F× R▢   BLOCKED

Blockers:
- Missing artifacts: 3 (placeholders: 1)
Next:
- wub assets export-all --anchors-pack ...
Receipts:
- runs/<id>/...
```

This makes first-run feel deterministic.

---

# Implementation plan (efficient and robust)

## Step 1 — Add a shared evaluator: `StudioState.evaluate()`

This is the core enabling move.

### Data model (minimal)

```swift
enum GateStatus { case pass, fail, warn, pending }

struct ReadinessGate {
  let key: String   // "A", "S", "I", "F", "R"
  let label: String // "Anchors", ...
  let status: GateStatus
  let detail: String? // e.g. "missing=3"
  let nextAction: String? // optional per-gate suggestion
}

struct StudioState {
  let gates: [ReadinessGate]          // in order
  let recommendedAction: MenuItem?    // or CLI command string
  let blockers: [String]
  let warnings: [String]
  let paths: PathsSummary             // lastRun, lastFailures, lastReports...
}
```

Evaluator responsibilities:

* Read anchors config
* Find latest receipts/reports (sweep/ready/drift/index) if present
* Compute missing/placeholder counts from artifact index
* Determine recommended next action (reuse existing logic; just make it return something consistent)

## Step 2 — Add a tiny renderer used by TUI + CLI

Create a function:

```swift
func renderReadinessBar(_ gates: [ReadinessGate]) -> String
```

Rules:

* `pass -> ▣`
* `pending -> ▢`
* `warn -> !`
* `fail -> ×`

Plus optional counts like `F×(3)`.

## Step 3 — Wire into Operator Shell header

In the TUI’s `printScreen`, add:

* readiness bar line as the **first** line
* include `next:` and “SPACE runs recommended action”

If recommended action is dangerous and user is in SAFE, add:

* “hidden in SAFE — press s”

## Step 4 — Add hover/selection details

When the user moves selection (up/down), show:

* Gate details (for the first failing gate)
* Or show details for the selected menu item (your Explain panel)

### Killer micro-interaction

If there is a failing gate, highlight it visually:

```
READY: A▣ S▣ I▣ [F×(3)] R▢
```

Even with plain ASCII you can bracket the failing segment.

## Step 5 — Make “Space” always perform the next readiness action

Space should run the **recommended next action**, which should correspond to the earliest failing gate:

* A fail → anchors select/set
* S fail → sweep
* I fail → index build
* F fail → assets export-all
* R fail/pending → ready verify (or repair flow if fail)

This makes onboarding fast and tactile.

---

# Documentation updates (small but high impact)

In `docs/first_run.md`, include a diagram explaining the bar:

```
READY:  A  S  I  F  R
        |  |  |  |  |
        |  |  |  |  +-- Ready verify (can I operate?)
        |  |  |  +----- Artifacts complete (no missing)
        |  |  +-------- Index built
        |  +----------- Sweep passes (no blocking modals)
        +-------------- Anchors configured
```

Also add “How to read the symbols” and “What to do if a segment fails.”

---

# Recommended next action mapping (crucial detail)

To avoid “mysterious recommendations,” define a deterministic policy:

1. Find the earliest gate with `fail`
2. Otherwise earliest `pending` (only if it matters)
3. Otherwise `ready verify` if never run (optional)
4. Otherwise CLEARED

Then recommended action is stable, predictable, and teachable.

---

# Quick win: do this even before `check/preflight` exists

You can ship the readiness bar **in PR1** using your existing internal logic and only a minimal evaluator, then expand it.

Even a partial bar is valuable:

* A (anchors known?)
* I (index present?)
* F (pending artifacts?)
* R (ready receipt?)

Then add Sweep next.

---

# Final note on naming

If you want the readiness bar to feel “music-native,” consider naming it in the UI:

* `READINESS` (simple)
* `PRE-FLIGHT` (if you want ceremony)
* `STATION` (if your mental model is “the studio is a station”)

But the segments should stay short (A/S/I/F/R) — people will learn them quickly.

---

If you want, I can also propose the exact header text + key legend so it reads like an instrument panel (not debug state), and aligns with the SAFE/GUIDED/ALL changes we discussed.

Below are **exact, copy-pasteable** header + key-legend proposals that (1) make the readiness bar the primary “instrument panel,” (2) make SAFE/GUIDED/ALL unambiguous, and (3) eliminate the misleading `all=ON` concept by presenting **View** truthfully.

I’m giving you **three naming variants** for the bar label—**READINESS**, **PRE-FLIGHT**, **STATION**—with identical structure so you can pick the vibe without changing the UI contract.

---

# 1) Header spec (exact text)

## Common symbols (used in all variants)

* `▣` PASS
* `▢` PENDING / unknown
* `!` WARN (non-blocking)
* `×` FAIL (blocking)

---

## Variant A: `READINESS` (simple, neutral)

### Header line 1 — readiness bar + next

```
READINESS  A▣  S▢  I▣  F×(3)  R▢    next: assets export-all   [SPACE]
```

### Header line 2 — mode + view (truthful about locks) + counts

SAFE:

```
mode: SAFE (9/20)   view: locked    (s: reveal)   (a: disabled)
```

GUIDED:

```
mode: GUIDED (12/20)   view: GUIDED (a)   (s: safe)
```

ALL:

```
mode: ALL (20/20)      view: ALL (a)      (s: safe)
```

### Header line 3 — anchors + station summary + last run pointers

```
Anchors: hvlien_v1    Station: detected    Last: runs/2026-02-02_143012
```

If anchors missing:

```
Anchors: NOT SET      Station: unknown     Last: —
```

### Optional header line 4 — only when something is hidden/blocked

If recommended action is hidden by SAFE:

```
note: next action is risky and hidden in SAFE — press s to reveal
```

If recommended action not visible in GUIDED:

```
note: next action not shown in GUIDED — press a for ALL
```

---

## Variant B: `PRE-FLIGHT` (ceremonial, “about to operate”)

### Header line 1

```
PRE-FLIGHT  A▣  S▢  I▣  F×(3)  R▢    next: assets export-all   [SPACE]
```

Everything else identical to Variant A. The label alone changes the tone.

---

## Variant C: `STATION` (studio-as-instrument; strong identity)

### Header line 1

```
STATION  A▣  S▢  I▣  F×(3)  R▢    next: assets export-all   [SPACE]
```

Again, everything else identical.

---

# 2) Gate labels (A/S/I/F/R) shown on demand

The bar stays compact (A/S/I/F/R), but users need a way to recall what each letter means without leaving the shell.

Add a one-key “legend overlay” (see key legend section) that prints:

```
A Anchors   S Sweep   I Index   F Files/Artifacts   R Ready
▣ pass   ▢ pending   ! warn   × fail
```

Keep it off the main header to preserve compactness.

---

# 3) Key legend (exact text)

You want this to read like an instrument panel, not a debug console.

## Minimal always-visible legend

This fits on one or two lines:

SAFE:

```
keys: ↑↓ select   ENTER run   SPACE run next   v voice   s safe/guided   ? help   q quit
```

GUIDED / ALL (where `a` works):

```
keys: ↑↓ select   ENTER run   SPACE run next   v voice   s safe   a view   ? help   q quit
```

## Help overlay content (triggered by `?`)

When `?` is pressed, show a compact overlay:

```
HELP
Bar: A Anchors  S Sweep  I Index  F Files/Artifacts  R Ready
Marks: ▣ pass  ▢ pending  ! warn  × fail

Modes:
SAFE   = hides risky actions (exports/fix/repair/certify)
GUIDED = curated essentials (includes some risky)
ALL    = full surface area

Keys:
↑↓ select   ENTER run selected   SPACE run next (recommended)
s toggle SAFE <-> GUIDED
a toggle GUIDED <-> ALL  (disabled in SAFE)
v toggle Voice Mode (numbers)
? this help   q quit
```

That’s enough for a first-time user to “get it” immediately.

---

# 4) Voice mode integration (make it explicit but not noisy)

When voice mode is ON, append a short suffix to the keys line:

```
keys: ↑↓ select   ENTER run   SPACE run next   v voice(ON)   1–9 speak/press   s safe   a view   ? help   q quit
```

When voice mode is OFF, don’t mention 1–9.

---

# 5) “Next action” affordance text (exact phrasing)

You want “next” to feel like a conductor cue: it should always be runnable and always explain itself if blocked/hidden.

### Default (visible & runnable)

```
next: assets export-all   [SPACE]
```

### If hidden by SAFE (danger item)

```
next: assets export-all   [SPACE]   (hidden in SAFE — press s)
```

### If not present in GUIDED view

```
next: drift fix   [SPACE]   (not shown in GUIDED — press a for ALL)
```

### If there is no next action (CLEARED)

```
next: —   CLEARED
```

---

# 6) Naming recommendation

If you want the UI to feel most “music-native” without overcommitting:

* **Use `STATION`** if the mental model is “the studio is a station you bring online.”
* **Use `PRE-FLIGHT`** if you want the shell to feel like a deliberate checklist before a session.
* **Use `READINESS`** if you want the cleanest, least-themed term.

My pick given your direction toward a creative OS: **STATION** (it feels like a persistent system, not a one-time checklist), and it pairs well with `wub preflight` as an *action* you run.

So: header label **STATION**, command **preflight**, state command **check**.

---

# 7) One small but important detail: “mode” should be singular and authoritative

Avoid presenting multiple toggles that imply more degrees of freedom than actually exist. The header should always communicate exactly one of:

* `mode: SAFE`
* `mode: GUIDED`
* `mode: ALL`

…with `view:` only when it’s genuinely selectable.

That single change eliminates the “all=ON” confusion permanently.

---

If you want, I can also propose the **exact spacing** and how to truncate paths cleanly (e.g., anchors pack name vs full path) so it stays readable on narrow terminals.
Here’s an exact, terminal-width-aware layout spec for the header, including **precise spacing rules** and **clean path truncation** that stays readable on narrow terminals.

---

## Header layout rules

### Terminal width

Let `W = terminalColumns` (fallback to 100 if unknown).

We’ll render **3 header lines** (4th is optional “note:”).

### Fixed components

* Gate bar is always fixed-width and aligned.
* “next:” area flexes and truncates.
* Paths are truncated **from the middle**, preserving meaningful ends.

---

## Line 1: Bar + next action

### Format (exact spacing)

```
{LABEL:<10}  A{A}  S{S}  I{I}  F{F}  R{R}    next: {NEXT}   [SPACE]
```

* `{LABEL:<10}` is left-aligned in 10 columns:

  * `"STATION"` fits (7)
  * `"READINESS"` fits (9)
  * `"PRE-FLIGHT"` fits (9)
* Two spaces after label.
* Two spaces between each gate pair.
* Four spaces before `next:`.
* Three spaces before `[SPACE]`.

### Gate token width

Each gate token is either:

* `A▣` / `S×` / `I▢` / `R!`
* For artifacts counts: `F×(3)` or `F▣`
  So **F token is variable width**; we’ll reserve up to **6 columns** for it and pad.

Recommended:

* Render `F` as:

  * `F▣` (2 cols) → pad to 6: `"F▣    "`
  * `F×(3)` (5 cols) → pad to 6: `"F×(3) "`

### How much space for `{NEXT}`

Compute fixed prefix length:

* Everything up to and including `"next: "` plus suffix `"   [SPACE]"`.

Then:

```
nextMax = W - fixedLen
NEXT = truncateMiddle(nextActionText, to: max(12, nextMax))
```

Rules:

* Minimum `{NEXT}` width = 12 chars (so it never collapses to nonsense).
* If `nextMax < 12`, drop `"   [SPACE]"` first, then drop `next:` label if necessary (rare). Prefer:

  1. remove ` [SPACE]`
  2. shorten `{NEXT}` to 8 min
  3. finally shorten label to `nx:` (last resort)

### Example widths

**W = 110**

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets export-all --anchors-pack hvlien_v1 --overwrite   [SPACE]
```

**W = 80**

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets export-all --overwrite   [SPACE]
```

**W = 60**

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets ex…write   [SPACE]
```

**W = 52** (starts dropping `[SPACE]`)

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets…write
```

---

## Line 2: Mode + view + counts

### Format (exact spacing)

SAFE:

```
mode: SAFE ({VIS}/{TOTAL})   view: locked   (s: reveal)   (a: disabled)
```

GUIDED / ALL:

```
mode: {MODE} ({VIS}/{TOTAL})   view: {VIEW} (a)   (s: safe)
```

Spacing rules:

* single space after `mode:`
* one space between `SAFE` and `({VIS}/{TOTAL})`
* **three spaces** between blocks (`...})   view: ...`)
* Keep `(s: ...)` and `(a: ...)` grouped at the end.

Truncation rule:

* If the line would exceed `W`, truncate from the right by dropping parentheticals in this order:

  1. drop `(a: disabled)` or `(s: safe)`
  2. drop `(s: reveal)`
  3. if still too long, drop `view:` block
  4. never drop `mode: ... ({VIS}/{TOTAL})`

---

## Line 3: Anchors + Station + Last run

### Format (exact spacing)

```
Anchors: {ANCH}    Station: {STATION}    Last: {LAST}
```

* `Anchors:` block first
* 4 spaces between blocks (`{ANCH}␠␠␠␠Station:`)
* 4 spaces between Station and Last

### Anchors rendering

Prefer:

* show **pack name** + **path**, but path is truncated.
* If you have only a path, derive pack name = last path component.

Format:

* If set:

  ```
  Anchors: hvlien_v1 • {PATH}
  ```
* If not set:

  ```
  Anchors: NOT SET
  ```

The bullet `•` reads well and visually separates name vs path.

### `PATH` truncation (clean + consistent)

Use **path-tail preservation**, because the end of paths is usually the most informative.

**Rule:** preserve the last 2 components + filename-ish end, preserve root marker.

Algorithm: `truncatePath(path, maxLen)`:

1. Normalize home:

   * If path starts with `/Users/<name>/`, replace with `~/`
2. Split components by `/`
3. If fits, return full (normalized)
4. Else return:

   ```
   {prefix}/{…}/{tail1}/{tail2}
   ```

   where:

   * prefix is `~/` or `/`
   * `tail1` and `tail2` are last two components (or last one if only one)
5. If still too long, fallback to pure middle truncation:

   * `truncateMiddle(normalizedPath, maxLen)`

Recommended max for `{ANCH}` block:

* allocate ~45% of `W` to anchors on line 3.
* e.g. `anchorMax = max(18, int(0.45 * W))`

### `LAST` truncation

`Last:` should prefer the end of the run id/path.
Use:

* `truncateTail(lastRunPath, maxLen)` (keeps tail)
  Example:
* `runs/2026-02-02_143012` fits
* if longer: `…/runs/2026-02-02_143012`

Allocate ~30% of `W` to Last:

* `lastMax = max(14, int(0.30 * W))`

### Example line 3

**W = 110**

```
Anchors: hvlien_v1 • ~/studio-operator/specs/automation/anchors/hvlien_v1    Station: detected    Last: runs/2026-02-02_143012
```

**W = 80**

```
Anchors: hvlien_v1 • ~/…/anchors/hvlien_v1    Station: detected    Last: …/2026-02-02_143012
```

**W = 60**

```
Anchors: hvlien_v1 • ~/…/hvlien_v1    Station: det.    Last: …143012
```

(At tight widths, abbreviate Station values: `det.` / `unk.` / `off`.)

---

## Optional Line 4: Notes (only when needed)

Only render if something is materially hidden/blocked.

Examples:

* Hidden in SAFE:

  ```
  note: next action is risky and hidden in SAFE — press s
  ```
* Not visible in GUIDED:

  ```
  note: next action not shown in GUIDED — press a for ALL
  ```

Truncate from right with `truncateTail(note, W)`.

---

## Truncation helpers (exact behavior)

### 1) `truncateMiddle(s, maxLen)`

* If `len(s) <= maxLen`: return `s`
* If `maxLen <= 1`: return `…` (or empty if you must)
* Else:

  * keep `head = (maxLen-1)/2`
  * keep `tail = maxLen-1-head`
  * return `s.prefix(head) + "…" + s.suffix(tail)`

Example:

* `assets export-all --anchors-pack hvlien_v1 --overwrite`
  → `assets exp…--overwrite` (depending on maxLen)

### 2) `truncateTail(s, maxLen)`

* If fits: return `s`
* Else: return `"…" + s.suffix(maxLen-1)`

### 3) `truncatePath(path, maxLen)`

* normalize `~/`
* if fits: return
* else `~/…/{last2}` pattern
* else fallback to `truncateTail` (paths are typically tail-useful)

---

## One practical note about “character width”

Unicode symbols like `▣` can be ambiguous in some terminals, but in most modern macOS terminals they display as single-cell. If you want to be absolutely safe, you can use ASCII equivalents:

* PASS `+`
* PENDING `.`
* WARN `!`
* FAIL `x`

But I’d keep `▣▢×!` unless you see alignment issues.

---

If you want, I can also propose the *exact* set of abbreviations for Station state (detected/unknown/offline) and the *exact* width allocations (percentages) for line 3 so it stays stable across terminals.

Great — here’s the continuation with **exact width allocations**, **station abbreviations**, and a **deterministic truncation policy** that will keep the header stable across narrow/wide terminals.

I’ll assume the bar label is **`STATION`** (best “instrument panel” vibe), but the spacing/truncation rules apply identically to READINESS / PRE-FLIGHT.

---

## Station state abbreviations

Keep the on-screen Station token short and consistent; show longer detail only in the help overlay.

### Canonical mapping

* `detected` → `det.`
* `unknown` → `unk.`
* `offline` / not running → `off`
* `blocked` (modal/permission preventing automation) → `blk`
* `busy` (optional: e.g., running a job) → `busy`

### Help overlay expansion

In `?` overlay, show the longer meaning:

* `det.` = detected
* `unk.` = unknown
* `blk` = blocked (modal/permissions)

---

## Header width allocation model

Let `W = terminalColumns` (fallback 100). We’ll treat the header as 3 lines with intentional “zones.”

### Line 1 zones

* Left: fixed readiness bar (“STATION  A▣ … R▢”)
* Right: `next:` + action (flex, truncates)
* Tail: `[SPACE]` (drops first when tight)

Line 1 should be the highest priority: **it must always render something meaningful**, even at W=50.

### Line 2 zones

* Always keep: `mode: … (x/y)`
* Prefer keep: `view: …`
* Drop parentheticals if tight

### Line 3 zones

We’ll allocate *percentage* budgets that adapt:

* Anchors block: **45%** of W (min 18)
* Station block: **15%** of W (min 12)
* Last block: **30%** of W (min 14)
* Remaining ~10% is separators and slack

If W is too tight, we progressively simplify (details below).

---

## Exact truncation policies

### String truncation primitives

#### `truncateMiddle(s, maxLen)`

* keep balanced head/tail around `…`
* best for commands (`next:`), because both beginning and end matter

#### `truncateTail(s, maxLen)`

* keep the end (`…suffix`)
* best for `runs/<id>` and paths when the tail is what you need

#### `truncatePath(path, maxLen)`

Path gets special treatment because the “shape” helps:

**Path normalization:**

* If path begins with `/Users/<name>/`, rewrite as `~/`
* If path begins with the repo root path (if known), rewrite as `./` (optional but excellent)

**First attempt (structured tail):**

* Keep root marker (`~/` or `/` or `./`)
* Keep last 2 path components
* Format: `~/…/tail1/tail2`

If that still exceeds `maxLen`, fall back to `truncateTail(normalizedPath, maxLen)`.

This yields stable, readable paths that don’t thrash visually.

---

## Line 3: exact formatting + adaptive simplification

### Preferred (W ≥ 90)

```
Anchors: {PACK} • {PATH}    Station: {ST}    Last: {LAST}
```

* `{PACK}` is last path component (or explicit pack name)
* `{PATH}` uses `truncatePath`
* `{ST}` uses abbreviations (`det.`/`unk.`/`off`/`blk`)
* `{LAST}` uses `truncateTail`

### Moderate width (70 ≤ W < 90): shorten Station label, keep anchors path

```
Anchors: {PACK} • {PATH}    Stn: {ST}    Last: {LAST}
```

(Just change `Station:` → `Stn:`)

### Tight (55 ≤ W < 70): drop anchors path, keep pack name only

```
Anchors: {PACK}    Stn: {ST}    Last: {LAST}
```

### Very tight (W < 55): drop Station block, keep anchors + last

```
Anchors: {PACK}    Last: {LAST}
```

This makes line 3 robust instead of turning into unreadable ellipses.

---

## Line 1: exact spacing + drop order

### Fixed left block

Render the readiness bar in a fixed-width region so it doesn’t jitter. Use this exact baseline:

```
STATION     A▣  S▢  I▣  F×(3)  R▢
```

**Spacing specifics:**

* `STATION` then **5 spaces** (so label area is 12 cols total)
* `A▣` then two spaces, etc.
* After `R?` add **4 spaces**, then `next:`

### Right block drop order

When `W` is too small:

1. Drop trailing `   [SPACE]`
2. Truncate `NEXT` via `truncateMiddle`
3. If still too tight, compress `next:` to `nx:`
4. If still too tight, remove label entirely and show only truncated action

#### Tightest acceptable (≈ 48–52 cols)

```
STATION     A▣  S▢  I▣  F×(3)  R▢    nx: assets…write
```

#### Absolute minimum (≈ 40–45 cols)

```
A▣ S▢ I▣ F×(3) R▢  assets…write
```

That last fallback can activate only when W is extremely small.

---

## Concrete width examples (so you can test visually)

Assume:

* pack = `hvlien_v1`
* anchors path = `~/studio-operator/specs/automation/anchors/hvlien_v1`
* last run = `runs/2026-02-02_143012`
* next action = `assets export-all --anchors-pack hvlien_v1 --overwrite`

### W = 110

Line 1:

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets export-all --anchors-pack hvlien_v1 --overwrite   [SPACE]
```

Line 2:

```
mode: SAFE (9/20)   view: locked   (s: reveal)   (a: disabled)
```

Line 3:

```
Anchors: hvlien_v1 • ~/studio-operator/specs/automation/anchors/hvlien_v1    Station: det.    Last: runs/2026-02-02_143012
```

### W = 80

Line 1:

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets export-all --… --overwrite   [SPACE]
```

Line 2:

```
mode: SAFE (9/20)   view: locked   (s: reveal)
```

Line 3:

```
Anchors: hvlien_v1 • ~/…/anchors/hvlien_v1    Stn: det.    Last: …02_143012
```

### W = 62

Line 1:

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: assets…write
```

Line 2:

```
mode: SAFE (9/20)   view: locked
```

Line 3:

```
Anchors: hvlien_v1    Stn: det.    Last: …143012
```

### W = 52

Line 1:

```
STATION     A▣  S▢  I▣  F×(3)  R▢    nx: assets…write
```

Line 2:

```
mode: SAFE (9/20)
```

Line 3:

```
Anchors: hvlien_v1    Last: …143012
```

---

## Implementation detail: compute widths deterministically

### Line 3 budgeting

Compute `anchorMax`, `stationMax`, `lastMax` like:

* `anchorMax = max(18, Int(0.45 * W))`
* `stationMax = max(12, Int(0.15 * W))`
* `lastMax = max(14, Int(0.30 * W))`

Then:

* `anchorsText = "Anchors: \(pack) • \(truncatePath(path, anchorMax - prefixLen))"`
* `stationText = "Station: \(abbr)"` or `Stn:`
* `lastText = "Last: \(truncateTail(lastRun, lastMax - prefixLen))"`

Finally assemble with `"    "` separators, and if it exceeds `W`, apply the simplification ladder (drop path, then station).

This avoids unpredictable truncation due to separator widths.

---

## One more “killer” micro-touch: show the first failing gate’s detail inline

When there’s a FAIL, append a short detail at the end of line 1 **only if space allows**:

Examples:

* Anchors missing:

  ```
  STATION ...    next: anchors select   [SPACE]   (Anchors not set)
  ```
* Artifacts missing:

  ```
  ... next: assets export-all [SPACE]   (3 missing)
  ```

Rule: only append if `W - len(line1) >= 12`.

This makes the bar not just a dashboard, but a guide.

---

If you want, I can also propose the exact `?` overlay layout that includes (1) the gate legend, (2) what SAFE/GUIDED/ALL do, and (3) the symbol key — formatted to fit in 60–80 columns cleanly.
Absolutely — here’s a **fully specified `?` help overlay** (exact text + spacing + width fallbacks) that stays readable at **60–80 columns**, plus the **rendering/truncation rules** so it never turns into mush.

I’ll keep the overlay “instrument panel”-like: short, scannable, and consistent with the header’s SAFE/GUIDED/ALL model and the readiness bar.

---

# `?` Help Overlay: exact layout

## Target width: 76–80 cols (primary)

```
┌────────────────────────────────────────────────────────────────────────────┐
│ HELP                                                                        │
│                                                                            │
│ Bar:  A Anchors   S Sweep   I Index   F Files/Artifacts   R Ready          │
│ Marks: ▣ pass   ▢ pending   ! warn   × fail                                 │
│                                                                            │
│ Modes:                                                                      │
│  SAFE   = hides risky actions (exports / fix / repair / certify)            │
│  GUIDED = curated essentials (some risky)                                   │
│  ALL    = full surface area                                                 │
│                                                                            │
│ Actions:                                                                    │
│  SPACE  run next (recommended)     ENTER  run selected                      │
│  ↑↓     move selection            v      voice mode (numbers)               │
│  s      SAFE <-> GUIDED           a      GUIDED <-> ALL (disabled in SAFE) │
│                                                                            │
│ Where to look when something fails:                                         │
│  runs/<id>/...  receipts + logs + screenshots (if any)                      │
│                                                                            │
│ Press ? to close                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Notes

* “Where to look…” reinforces your receipt-driven model.
* Keeps the overlay self-contained: user learns bar + symbols + modes + keys + recovery.

---

## Width fallback: 68–75 cols (compact)

When `W < 76`, drop some words, shorten line lengths, keep structure.

```
┌──────────────────────────────────────────────────────────────────────┐
│ HELP                                                                 │
│                                                                      │
│ Bar:  A Anchors  S Sweep  I Index  F Artifacts  R Ready              │
│ Marks: ▣ pass  ▢ pending  ! warn  × fail                             │
│                                                                      │
│ Modes:                                                               │
│  SAFE   hides risky actions (exports/fix/repair/certify)             │
│  GUIDED curated essentials (some risky)                              │
│  ALL    full surface area                                            │
│                                                                      │
│ Keys:                                                               │
│  SPACE next   ENTER run   ↑↓ select   v voice   s safe/guided   a all │
│  ? close                                                        q quit│
│                                                                      │
│ Logs: runs/<id>/...                                                  │
└──────────────────────────────────────────────────────────────────────┘
```

**Key change:** the keys line becomes denser but still parseable.

---

## Width fallback: 58–67 cols (tight but still useful)

At this width, an ASCII box is still fine, but reduce vertical complexity.

```
┌──────────────────────────────────────────────────────────┐
│ HELP                                                     │
│                                                          │
│ A Anchors  S Sweep  I Index  F Artifacts  R Ready         │
│ ▣ pass  ▢ pending  ! warn  × fail                         │
│                                                          │
│ SAFE hides risky   GUIDED curated   ALL everything        │
│                                                          │
│ SPACE next   ENTER run   ↑↓ select   v voice              │
│ s SAFE<->GUIDED    a GUIDED<->ALL (not in SAFE)          │
│                                                          │
│ Logs: runs/<id>/...                                      │
│ Press ? to close                                         │
└──────────────────────────────────────────────────────────┘
```

---

## Ultra-tight fallback: < 58 cols (no box; “panel text”)

At very small widths, the box becomes more harmful than helpful. Switch to a simple block:

```
HELP
A Anchors  S Sweep  I Index  F Artifacts  R Ready
▣ pass  ▢ pending  ! warn  × fail

SAFE hides risky. GUIDED curated. ALL full.
SPACE next  ENTER run  ↑↓ select  v voice
s SAFE<->GUIDED  a GUIDED<->ALL (not in SAFE)

Logs: runs/<id>/...
(? to close)
```

---

# Rendering rules (deterministic)

## 1) Overlay width & padding

* If `W >= 58`: render a box.
* Box width `BW = min(80, W)` (cap at 80 so it looks consistent).
* Inner content width `IW = BW - 4` (box borders + padding).
* Every text line should be:

  * `"│ " + padRight(content, IW) + " │"`
* Title line uses `HELP` and pads the rest.

## 2) Line truncation

Any content line longer than `IW` must be truncated.

Use:

* `truncateTail(line, IW)` for most help text (keeps the important ending)
* except for command-like lines (rare in help), where `truncateMiddle` is better.

## 3) Box drawing characters

If you see terminals with poor Unicode box support, you can switch to ASCII:

* `+-----+` style
  But I’d default to Unicode box; it’s widely supported on macOS terminals.

---

# Additional “instrument panel” touches (optional but high-value)

## A) Show current mode in the overlay header

If you can compute current mode (`SAFE|GUIDED|ALL`), show:

Top line:

```
│ HELP (mode: SAFE)                                                       │
```

This anchors the user and makes `a` being disabled feel natural.

## B) Show current readiness status summary

If there’s a failing gate, include a 1-line summary in help:

For example (only if space allows):

```
│ Current: F× missing artifacts (3) — next: assets export-all             │
```

This turns help into a “what’s going on” lens, not just documentation.

---

# Truncation examples (so it’s predictable)

### If IW=64 and the “Where to look…” line is too long:

Original:
`Where to look when something fails:`
Truncated (tail):
`Where to look when something fails:`
(fits; no change)

If a longer line overflows:
`SAFE = hides risky actions (exports / fix / repair / certify)`
becomes (tail-truncate to 64):
`SAFE = hides risky actions (exports / fix / repair / certi…)`

For the keys line, if it overflows, prefer dropping less important tokens first:

1. drop `q quit`
2. shorten `voice mode (numbers)` to `voice`
3. shorten `disabled in SAFE` to `not in SAFE`

This keeps the help meaningful even when cramped.

---

# Final: exact “Keys line” copy to standardize everywhere

Use this exact order (same in header and help) so muscle memory forms:

* Navigation → Execution → Mode → View → Voice → Help/Quit

Canonical ordering:

```
↑↓ select   ENTER run   SPACE next   s SAFE/GUIDED   a GUIDED/ALL   v voice   ? help   q quit
```

In SAFE, render `a` as disabled in both places:

```
↑↓ select   ENTER run   SPACE next   s SAFE/GUIDED   a (disabled)   v voice   ? help   q quit
```

---

If you want, next I can propose the **exact on-screen “toast” messages** for when a user presses a disabled key (`a` in SAFE), and for when an action is hidden by SAFE or GUIDED — those microcopy details are what make the shell feel “obvious” rather than “clever.”
Perfect — toasts are where this stops feeling like a clever UI and starts feeling *obvious*. Below is a **complete, opinionated toast system** with **exact copy**, **trigger conditions**, **severity levels**, **display duration**, and **placement rules**. You can implement this verbatim.

---

# Toast system: design goals

Toasts should be:

* **Short** (≤ 2 lines, ideally 1)
* **Action-oriented** (always tell you what to do next)
* **Non-judgmental** (no “error”, no blame)
* **Contextual** (only appear when the user *tries* something)

They should *never* feel like alerts. Think “console whisper,” not warning dialog.

---

# Placement & behavior (global rules)

* **Location**: bottom of the screen, above the key legend
* **Style**: single-line, prefixed with a subtle symbol
* **Duration**:

  * Informational: 1.5s
  * Blocked action: 2.5s
  * Success confirmation: 1.2s
* **Stacking**: never stack; newest replaces previous
* **Dismissal**: auto-dismiss only (no manual close)

### Prefix symbols (ASCII-safe)

* `•` informational
* `!` blocked / attention
* `✓` success

---

# Core toast messages (exact copy)

## 1) Pressing `a` in SAFE mode (view toggle disabled)

**Trigger**

* User presses `a`
* `mode == SAFE`

**Toast**

```
! View is locked in SAFE — press s to reveal guided actions
```

Why this works:

* Explains *why* nothing happened
* Teaches the mental model (“SAFE locks view”)
* Gives exact next key

---

## 2) Pressing `a` when already in ALL

**Trigger**

* User presses `a`
* `mode == ALL`

**Toast**

```
• Already showing all actions
```

Short, confirms state, no extra instruction.

---

## 3) Recommended action is hidden by SAFE

**Trigger**

* `recommendedAction.danger == true`
* `mode == SAFE`
* User tries SPACE or ENTER on a different item

**Toast**

```
! Next action is risky and hidden — press s to proceed
```

This pairs perfectly with the header note but reinforces it *at the moment of friction*.

---

## 4) Recommended action not visible in GUIDED view

**Trigger**

* `mode == GUIDED`
* `recommendedAction` exists but not in visible menu
* User presses SPACE

**Toast**

```
• Next action not shown in GUIDED — press a for ALL
```

Key detail: we say “not shown”, not “missing”.

---

## 5) Attempting to run a dangerous action (confirmation moment)

You already have guarded prompts — this toast *prepares* the user before the prompt.

**Trigger**

* User selects a `danger == true` action
* About to show confirmation prompt

**Toast**

```
! This action modifies the studio state — confirmation required
```

Duration: short (1s), then prompt appears.

---

## 6) User declines a dangerous action

**Trigger**

* User cancels confirmation prompt

**Toast**

```
• Action cancelled — studio state unchanged
```

Reassures safety; no shame.

---

## 7) Successful command completion (generic)

**Trigger**

* Command exits 0
* Not a “major” milestone

**Toast**

```
✓ Completed successfully
```

Keep it boring. Success should be quiet.

---

## 8) Successful completion of a readiness milestone

Use this for steps that advance the readiness bar.

### Examples

**After anchors selection**

```
✓ Anchors configured
```

**After sweep passes**

```
✓ Sweep passed — no blocking modals detected
```

**After index build**

```
✓ Index built
```

**After export-all**

```
✓ Artifacts generated
```

**After ready verify**

```
✓ Studio ready
```

These reinforce progress and teach the pipeline implicitly.

---

## 9) Command failed (generic failure)

**Trigger**

* Command exits non-zero

**Toast**

```
! Action failed — see runs/<id>/ for details
```

If you can substitute `<id>` with a short tail (`…143012`), do it.

---

## 10) Command failed with a known blocker (better UX)

If your evaluator can classify the failure:

### Examples

**Sweep blocked**

```
! Sweep blocked by modal or permission
```

**Artifacts missing**

```
! Missing artifacts detected
```

**Ready verify failed**

```
! Studio not ready — verification failed
```

These should be followed by:

* Header `next:` update
* Optional detailed output in the main pane

---

## 11) Pressing SPACE when there is no next action (CLEARED)

**Trigger**

* `recommendedAction == nil`
* User presses SPACE

**Toast**

```
• No pending actions — studio is ready
```

This feels *good* and confirms completion.

---

## 12) Toggling SAFE/GUIDED/ALL (mode feedback)

### SAFE → GUIDED

```
• Guided mode — essential actions visible
```

### GUIDED → SAFE

```
• Safe mode — risky actions hidden
```

### GUIDED → ALL

```
• All actions visible
```

### ALL → GUIDED

```
• Guided mode — essential actions only
```

This teaches the meaning of modes through repetition.

---

## 13) Voice mode toggles

### Voice ON

```
• Voice mode enabled — say or press numbers
```

### Voice OFF

```
• Voice mode disabled
```

---

## 14) Anchors missing (early, critical hint)

**Trigger**

* Evaluator detects no anchors pack
* User tries to run almost anything

**Toast**

```
! Anchors not configured — select anchors to proceed
```

This prevents the “why does nothing work?” feeling.

---

# Priority & suppression rules (important)

Toasts should not spam.

### Suppress rules

* Don’t show the same toast twice within 3 seconds
* Don’t show informational toasts while a command is actively running
* Blocked-action toasts always override informational ones

### Priority order

1. Blocked (`!`)
2. Success (`✓`)
3. Informational (`•`)

---

# Exact rendering style

### Visual format (single line)

```
• Guided mode — essential actions visible
```

* One leading symbol
* One space
* Sentence case
* No trailing punctuation

### Color (optional but recommended)

* `✓` green
* `•` neutral / dim
* `!` amber (not red — red feels punitive)

---

# One final “killer” micro-copy

When a user presses a key that does *nothing* (no-op), **always toast**. Silence is what causes confusion.

Examples:

* `a` in SAFE → toast #1
* SPACE with no next → toast #11
* ENTER on disabled item → toast:

  ```
  ! Action unavailable in current mode
  ```

---

## Why this works

* Users learn the system *by touching it*
* Every confusion point produces a helpful sentence
* The system never feels broken — only constrained, and always explainable

If you want, next I can:

* map each toast to exact Swift trigger points in your Operator Shell loop, and
* propose a tiny `ToastManager` abstraction with throttling and priority baked in.

Yes — here’s both:

1. a **precise map** from each toast to the **exact trigger points** in your current Operator Shell loop, and
2. a **tiny `ToastManager`** abstraction (with **priority + throttling + expiry**) that plugs into your existing `while true { … readKey(); switch key { … } }` structure.

All references below are in `tools/automation/swift-cli/Sources/StudioCore/OperatorShellCommand.swift`. 

---

## 1) Map each toast → exact Swift trigger points

### Where to store toast state

Add a `ToastManager` instance alongside your existing transient state (`lastCommandExit`, `lastReceiptPath`, etc.) right after modes are initialized. 

```swift
var toast = ToastManager()
```

Then pass `toast.currentText` (if any) into `printScreen(...)` (you’ll extend the signature). Right now `printScreen` renders the “modes/keys” section at lines 423–427 — that’s exactly where the toast should appear (just above the keys line). 

---

### Toast triggers inside the key loop (`switch key`)

Your loop is here: `let key = readKey(); switch key { … }` 

#### (A) Pressing `a` in SAFE (view toggle disabled)

Today, `a` always maps to `.toggleAll` in `readKey()` , and `.toggleAll` always toggles `showAll`  — but `showAll` is ignored when `studioMode == true` in `visibleItems` , which is the root of confusion.

**Trigger point:** `case .toggleAll:` 

**Logic:**

* if `studioMode == true`: don’t toggle `showAll`; toast blocked message
* else: toggle view and toast which view you’re in

**Toast text:**

* `! View is locked in SAFE — press s to reveal guided actions`

---

#### (B) Toggling SAFE/GUIDED (currently `s`)

**Trigger point:** `case .toggleStudioMode:` 

**Toast text (exact):**

* SAFE → GUIDED: `• Guided mode — essential actions visible`
* GUIDED/ALL → SAFE: `• Safe mode — risky actions hidden`

---

#### (C) Toggling Voice mode (`v`)

**Trigger point:** `case .toggleVoiceMode:` 

**Toast:**

* ON: `• Voice mode enabled — say or press numbers`
* OFF: `• Voice mode disabled`

---

#### (D) SPACE (run recommended)

SPACE maps to `.runRecommended` in `readKey()`  and runs `runAction` if `rec.action` exists .

**Trigger point:** `case .runRecommended:` 

**Toasts:**

* If `rec.action == nil`: `• No pending actions — studio is ready`
  (This matches your “anchors not set” case too: recommended summary can say anchors missing but `action` is nil. )
* If action exists but is **dangerous** and you’re in SAFE: `! Next action is risky and hidden — press s to proceed`
  (You’ll implement “recommended hidden in SAFE” by comparing `rec.action.danger` with `studioMode`; action carries `danger`. )
* If action exists and you run it: show success/fail toast based on exit code captured in `runAction` (below).

---

#### (E) ENTER (run selected)

**Trigger point:** `case .enter:` 

**Toasts:**

* If selected item is dangerous and you’re in SAFE (it shouldn’t be visible because SAFE filters danger , but this is defensive): `! Action unavailable in SAFE — press s`
* Else: run it, then set success/failure toast based on exit

---

#### (F) Number selection in voice mode

Numbers map to `.selectNumber(Int)`  and run `runAction` immediately .

**Trigger point:** `case .selectNumber(let n):` 

**Toast:**

* If `n` out of range (currently silently ignored): `• No action at that number`
* Otherwise: run, then success/fail toast

---

### Toast triggers inside `runAction(...)`

`runAction` is your execution gate and already handles dangerous confirmation and exit/result printing. 

#### (G) Dangerous confirmation prompt

**Trigger point:** `if action.danger && !dryRun { … Proceed? [y/N] … }` 

**Toast:**

* Before showing the prompt: `! This action modifies the studio state — confirmation required`
* If user cancels: `• Action cancelled — studio state unchanged`

You currently `return` silently on cancel (`if ans != "y" … { return }`).  This is a perfect place to add the cancel toast.

#### (H) Command success / failure

**Trigger point:** after `let code = … runProcess(...)` and `lastExit = code` 

**Toast:**

* `code == 0`: `✓ Completed successfully`
* else: `! Action failed — see runs/<id>/ for details` (you already compute lastRunDir + receipt + failures dir right there )

> Later, once you have the readiness evaluator + readiness bar, you can swap “Completed successfully” for milestone-specific success toasts by checking which gate transitioned.

---

## 2) A tiny `ToastManager` abstraction

This gives you:

* **Priority** (blocked > success > info)
* **Throttling** (don’t repeat the same toast too often)
* **Expiry** (auto-dismiss after N seconds)
* **Non-stacking** (new replaces old)

### Drop-in Swift code

```swift
// ToastManager.swift (or keep inside OperatorShellCommand.swift)

import Foundation

struct ToastManager {
  enum Level: Int, Comparable {
    case info = 0
    case success = 1
    case blocked = 2

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
  }

  struct Toast: Equatable {
    let level: Level
    let message: String
    let createdAt: Date
    let expiresAt: Date
    let key: String  // used for throttling (e.g., "view_locked_safe")
  }

  // Current toast (if not expired)
  private(set) var current: Toast? = nil

  // Last-shown timestamps per key (throttle)
  private var lastShown: [String: Date] = [:]

  // Default throttle (same toast key)
  var throttleWindow: TimeInterval = 3.0

  mutating func tick(now: Date = Date()) {
    if let t = current, now >= t.expiresAt {
      current = nil
    }
  }

  var currentText: String? {
    guard let t = current else { return nil }
    let prefix: String
    switch t.level {
    case .info: prefix = "•"
    case .success: prefix = "✓"
    case .blocked: prefix = "!"
    }
    return "\(prefix) \(t.message)"
  }

  mutating func show(
    _ message: String,
    level: Level,
    key: String,
    ttl: TimeInterval,
    now: Date = Date()
  ) {
    // throttle identical key
    if let last = lastShown[key], now.timeIntervalSince(last) < throttleWindow {
      return
    }

    // priority: only replace current if higher/equal priority OR current expired
    if let cur = current, now < cur.expiresAt, level < cur.level {
      return
    }

    let toast = Toast(
      level: level,
      message: message,
      createdAt: now,
      expiresAt: now.addingTimeInterval(ttl),
      key: key
    )
    current = toast
    lastShown[key] = now
  }

  // Convenience helpers
  mutating func info(_ msg: String, key: String, ttl: TimeInterval = 1.5) {
    show(msg, level: .info, key: key, ttl: ttl)
  }

  mutating func success(_ msg: String, key: String, ttl: TimeInterval = 1.2) {
    show(msg, level: .success, key: key, ttl: ttl)
  }

  mutating func blocked(_ msg: String, key: String, ttl: TimeInterval = 2.5) {
    show(msg, level: .blocked, key: key, ttl: ttl)
  }
}
```

---

## Wiring `ToastManager` into your existing loop

### A) Add toast manager & tick each frame

Right inside `run()` after transient state:

```swift
var toast = ToastManager()
```

Then, at the top of `while true {` loop, tick it:

```swift
toast.tick()
```

This sits naturally alongside your “dynamic filtered view” computation. 

### B) Extend `printScreen` to render toast

Add a `toastLine: String?` parameter to `printScreen(...)` (you already pass a lot there). 

Render it just above the “keys:” line, since that’s where the user’s eyes go. Right now you print `modes:` and then `keys:` at lines 424–425. 

Example:

```swift
if let tl = toastLine {
  print(tl)
}
print("keys: ...")
```

### C) Modify specific switch cases

#### `.toggleAll` (your `a` key)

Replace your current behavior:

```swift
case .toggleAll:
  showAll.toggle()
  selected = 0
  continue
```

with:

```swift
case .toggleAll:
  if studioMode {
    toast.blocked("View is locked in SAFE — press s to reveal guided actions", key: "view_locked_safe")
    continue
  }
  showAll.toggle()
  selected = 0
  toast.info(showAll ? "All actions visible" : "Guided mode — essential actions only", key: "view_toggle")
  continue
```

Why: `visibleItems` ignores `showAll` when `studioMode` is true , so this toast makes that explicit.

#### `.toggleStudioMode` (your `s` key)

```swift
case .toggleStudioMode:
  studioMode.toggle()
  selected = 0
  toast.info(studioMode ? "Safe mode — risky actions hidden" : "Guided mode — essential actions visible",
             key: "studio_toggle")
  continue
```

#### `.toggleVoiceMode`

```swift
case .toggleVoiceMode:
  voiceMode.toggle()
  toast.info(voiceMode ? "Voice mode enabled — say or press numbers" : "Voice mode disabled",
             key: "voice_toggle")
  continue
```

#### `.runRecommended` (SPACE)

Currently: run action if present; otherwise just continue. 

Upgrade:

```swift
case .runRecommended:
  guard let action = rec.action else {
    toast.info("No pending actions — studio is ready", key: "no_next_action", ttl: 1.8)
    continue
  }
  if action.danger && studioMode {
    toast.blocked("Next action is risky and hidden — press s to proceed", key: "next_hidden_safe")
    continue
  }
  try await runActionWithToasts(action, toast: &toast, stdinRaw: stdinRaw, dryRun: dryRun,
                               lastExit: &lastCommandExit, lastReceipt: &lastReceiptPath,
                               lastRunDir: &lastRunDir, lastFailuresDir: &lastFailuresDir)
  continue
```

---

## `runActionWithToasts`: minimal wrapper around your existing `runAction`

Because `runAction` currently blocks the UI and prints “Press Enter to return…” , you have two options:

* **Phase 1 (minimal change):** keep `runAction` behavior; just set toasts *after it returns*.
* **Phase 2 (best UX):** change `runAction` so it doesn’t leave the TUI; instead capture output to a log view and return quickly. (This is a larger UX refactor.)

Here’s Phase 1 wrapper:

```swift
func runActionWithToasts(
  _ action: UI.RecommendedAction.Action,
  toast: inout ToastManager,
  stdinRaw: StdinRawMode,
  dryRun: Bool,
  lastExit: inout Int32?,
  lastReceipt: inout String?,
  lastRunDir: inout String?,
  lastFailuresDir: inout String?
) async throws {

  // Pre-toast for dangerous
  if action.danger && !dryRun {
    toast.blocked("This action modifies the studio state — confirmation required", key: "danger_confirm", ttl: 1.0)
  }

  let beforeExit = lastExit
  try await runAction(action, stdinRaw: stdinRaw, dryRun: dryRun,
                      lastExit: &lastExit, lastReceipt: &lastReceipt,
                      lastRunDir: &lastRunDir, lastFailuresDir: &lastFailuresDir)

  // If user cancelled, runAction returns without changing lastExit (usually)
  if beforeExit == lastExit && action.danger && !dryRun {
    toast.info("Action cancelled — studio state unchanged", key: "danger_cancel", ttl: 1.8)
    return
  }

  if let code = lastExit {
    if code == 0 {
      toast.success("Completed successfully", key: "action_ok", ttl: 1.2)
    } else {
      // Prefer lastRunDir tail if available
      let tail = lastRunDir.map { "see \($0)" } ?? "see runs/<id>/"
      toast.blocked("Action failed — \(tail) for details", key: "action_fail", ttl: 2.5)
    }
  }
}
```

---

## Small but important: toasts must be shown in the UI, not in the “cooked mode” subviews

Your `.previewDriftPlan`, `.readyVerify`, `.repairRun` cases currently disable raw mode, print a separate screen, then return. 
You can still set a toast *after* re-enabling raw mode (“✓ Completed successfully” or “! Action failed …”) if you convert those “cooked mode” helpers to return a code.

---

## Summary: exactly where each toast plugs in

* **Key loop (switch key)**: add toasts for mode toggles, disabled view toggles, missing actions. 
* **`visibleItems` reality**: use toasts to explain why `a` is a no-op in SAFE. 
* **`runAction`**: pre-toast for dangerous confirmation and post-toast for success/failure. 
* **`printScreen`**: render toast line just above keys. 

---

If you want the next increment after this: refactor `runAction` to avoid leaving the TUI (replace “Press Enter to return…”  with an in-TUI “log pane”), which makes toasts feel instantaneous and keeps the readiness bar alive while commands run.
Yep — next increment is to stop “dropping out” of the Operator Shell into those cooked-mode full-screen command runners (and especially to remove the “Press Enter to return…” flow ). Once you keep everything *inside* the TUI, your toasts + readiness bar become continuously useful, and first-time users don’t lose context.

Below is a concrete design + exact integration points for an **in-TUI Log Pane + non-blocking command runner**, building on your current loop structure.

---

# Phase 2 UX: keep execution inside the TUI

## Desired behavior

When an action runs:

* Header stays visible (readiness bar, mode/view, anchors)
* Main pane becomes a **log view** for the running command
* User can:

  * cancel (optional)
  * return to menu without losing the output
* On completion:

  * show a success/fail toast
  * update “Last: runs/…”
  * recompute readiness + recommended next action

---

# Minimal architecture: `CommandRunner` + `LogBuffer`

## 1) `LogBuffer` (small, in-memory tail)

Keep only the last N lines (e.g., 400–1000) to avoid memory growth.

```swift
struct LogBuffer {
  var lines: [String] = []
  let maxLines: Int = 600

  mutating func append(_ line: String) {
    lines.append(line)
    if lines.count > maxLines {
      lines.removeFirst(lines.count - maxLines)
    }
  }

  func tail(_ n: Int) -> [String] {
    if lines.count <= n { return lines }
    return Array(lines.suffix(n))
  }
}
```

## 2) `CommandRunner` (non-blocking state machine)

This lets your key loop stay responsive.

```swift
enum RunState {
  case idle
  case confirming(UI.RecommendedAction.Action)
  case running(action: UI.RecommendedAction.Action, startedAt: Date)
  case finished(action: UI.RecommendedAction.Action, exit: Int32, finishedAt: Date)
}

struct CommandRunner {
  var state: RunState = .idle
  var log = LogBuffer()
  var lastExit: Int32? = nil
  var lastRunDir: String? = nil
  var lastFailuresDir: String? = nil
  var lastReceiptPath: String? = nil
}
```

---

# Integration points in your Operator Shell

Everything happens inside `OperatorShellCommand.run()` in `OperatorShellCommand.swift`.

## A) Add runner + toast to the top-level state

Near where you already declare mode flags and last paths (same area you added toasts earlier): 

```swift
var toast = ToastManager()
var runner = CommandRunner()
var showLogs = false   // toggles “log pane” vs “menu pane”
var logScroll = 0      // 0 = bottom; >0 = scrollback lines
```

## B) Change your `printScreen(...)` signature to accept:

* `toastLine`
* `runner` state
* `showLogs` + `logScroll`

Render:

* Header (readiness bar, mode/view, anchors)
* Then either:

  * **menu list** (existing)
  * **log pane** (new)

### Log pane rendering (exact behavior)

* If `showLogs == true`:

  * print a title row:

    * `LOG  <action title>   (running…)`
  * then print last N lines of runner.log with scrolling
  * bottom row shows:

    * `keys: ↑↓ scroll  ESC back  ENTER run  SPACE next  q quit`
* If `showLogs == false`:

  * show normal menu + explain panel + keys

> This avoids a “modal UI.” Logs are just a view toggle.

## C) Add key bindings for log view

Extend your `Key` enum and `readKey()` (near the mapping you already have) 

Suggested new keys:

* `l` toggle logs
* `ESC` back to menu from logs
* In logs:

  * `j/k` or arrow up/down scroll

To keep it minimal, reuse `up/down` for scroll when `showLogs == true`.

---

# Command execution: replace `runAction` with async streaming

Today `runAction` does:

* optional confirm
* run process
* print “Exit: …”
* wait for Enter to return 

We’ll refactor into:

1. a **confirm step** that stays in TUI (toast + a minimal prompt row)
2. a **Process** that streams stdout/stderr lines into `runner.log`
3. completion updates runner fields + toast

## 1) Confirmation inside the loop (no cooked mode)

When user triggers a dangerous action:

* set `runner.state = .confirming(action)`
* show a prompt line in the UI (not in stdin cooked mode)

### Prompt line (exact UI copy)

At bottom (above keys) show:

```
confirm: This action modifies studio state. Proceed?  (y)es / (n)o
```

Then handle `y/n` key events inside the key loop:

* `y` -> start run
* `n` -> cancel (toast: “Action cancelled — studio state unchanged”) and return to idle

This removes `readLine()` entirely.

## 2) Running process with streaming output

You already have `runProcess(...)` as a helper, but it appears to be blocking and not streaming into the UI. 

### Minimal streaming runner (conceptual)

Use `Process`, `Pipe`, and readability handlers to append lines.

Pseudo-implementation:

```swift
func startProcessStreaming(
  command: String,
  args: [String],
  onLine: @escaping (String) -> Void,
  onExit: @escaping (Int32) -> Void
) throws {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: command)
  p.arguments = args

  let pipe = Pipe()
  p.standardOutput = pipe
  p.standardError = pipe

  let handle = pipe.fileHandleForReading
  handle.readabilityHandler = { h in
    let data = h.availableData
    if data.isEmpty { return }
    if let s = String(data: data, encoding: .utf8) {
      // split into lines; keep partials if needed
      s.split(whereSeparator: \.isNewline).forEach { onLine(String($0)) }
    }
  }

  p.terminationHandler = { proc in
    handle.readabilityHandler = nil
    onExit(proc.terminationStatus)
  }

  try p.run()
}
```

### Where this plugs in

When entering `.running`, call `startProcessStreaming(...)` and immediately:

* set `showLogs = true`
* toast: `• Running: <action title>` (optional info)

As lines arrive, append to `runner.log` and re-render on next loop tick.

> If your loop is event-driven and only re-renders on keypress, add a simple `refreshTimer` tick (e.g., 10 Hz) or use `readKey` with timeout. If that’s too big a change, you can still render on keypress for phase 1.

## 3) Completion handling (exit status)

In `onExit(code)`:

* update runner:

  * `runner.lastExit = code`
  * set `.finished(...)`
* compute last run dir / receipt path the same way you currently do in `runAction` (you already compute `outDir`, `receipt`, `failuresDir`) 
* toast success/fail:

  * success: `✓ Completed successfully`
  * fail: `! Action failed — see runs/<id>/ for details`
* trigger a refresh of readiness evaluator (once you add it)

---

# Exact toast mapping adjustments for the new in-TUI runner

Once you remove cooked mode, toasts become very clean:

## When starting a dangerous action:

* `! This action modifies the studio state — confirmation required` (blocked, 1.0s)

## When user presses `n`:

* `• Action cancelled — studio state unchanged` (info, 1.8s)

## When starting actual run:

* `• Running — logs opened` (info, 1.2s) [optional]

## When finished:

* success: `✓ Completed successfully`
* fail: `! Action failed — see runs/<id>/ for details`

---

# Making readiness bar update live

Once you have the `StudioState.evaluate()` (your shared evaluator), do this:

* Evaluate at loop start (or every N seconds) to compute:

  * gates A/S/I/F/R
  * recommended next action
* After any command finishes, force re-evaluation immediately.

This makes the readiness bar feel like a live instrument panel:

* export-all completes → `F×(3)` becomes `F▣`
* ready verify completes → `R▣`
* user sees it change without leaving the UI

---

# Minimal UI copy for log pane

### Log pane header (exact)

When running:

```
LOG  Assets: export ALL   (running)
```

When finished:

```
LOG  Assets: export ALL   (exit: 0)
```

If failed:

```
LOG  Assets: export ALL   (exit: 1)   see: runs/…143012
```

### Log pane keys (exact)

```
keys: ↑↓ scroll   0 bottom   ESC back   q quit
```

* `0` jumps to bottom (great for tails)
* ESC returns to menu while preserving logs

---

# Concrete refactor steps (so this doesn’t sprawl)

## PR2a: Introduce runner + logs (keep existing `runAction` temporarily)

* Add `ToastManager` rendering and basic toasts (already planned)
* Add `showLogs` view and `LogBuffer` + placeholder logs
* Add `l` to open logs
* Still use current `runAction` for execution (no streaming yet)

## PR2b: Replace `runAction` with non-blocking streaming

* Implement `startProcessStreaming`
* Add `.confirming` and handle `y/n` in key loop
* Remove `readLine()` and “Press Enter to return…” flow
* Stream stdout/stderr to log pane
* Add completion toasts + link to runs folder

This keeps reviewable chunks and lets you land improvements without destabilizing operator flow.

---

# One more “killer” touch: persist last logs to disk

When the command runs, you already have a run directory. When you stream a line:

* append also to a file: `runs/<id>/operator_shell.log`

Then even if the user exits the TUI, everything is recoverable and consistent with your receipt model.

---

If you want, I can draft the **exact diff-level change list** for `OperatorShellCommand.swift` (new structs, new switch cases, changes to `printScreen`, and the process streaming helper) using the code structure you already have in that file.

Here’s the **diff-level change list** to land the “in-TUI runner + log pane” upgrade cleanly, building directly on your current `OperatorShellCommand.swift` structure.

I’m going to assume you’ll do this in two passes:

* **PR2a**: Log pane + state machine scaffolding (still uses existing `runAction` temporarily)
* **PR2b**: True streaming runner + remove “Press Enter to return…”

I’ll call out **exact insertion points** using the current file’s structure and key lines.

---

# PR2a — Log Pane + Runner State (minimal disruption)

## 1) Add new tiny types (either new files or top of OperatorShellCommand.swift)

### Option A (clean): new files in `Sources/StudioCore/`

* `ToastManager.swift` (the code I provided earlier)
* `LogBuffer.swift`
* `CommandRunner.swift`

### Option B (fast): put them at bottom of `OperatorShellCommand.swift`

You already have helper types/functions at the bottom (e.g., `readKey` mapping etc.). 

Add:

**LogBuffer**

```swift
struct LogBuffer {
  var lines: [String] = []
  var maxLines: Int = 600

  mutating func append(_ line: String) {
    lines.append(line)
    if lines.count > maxLines {
      lines.removeFirst(lines.count - maxLines)
    }
  }

  func window(count: Int, scroll: Int) -> [String] {
    // scroll=0 means bottom; scroll>0 means show earlier lines
    let total = lines.count
    let end = max(0, total - scroll)
    let start = max(0, end - count)
    return Array(lines[start..<end])
  }
}
```

**RunState + Runner**

```swift
enum RunState: Equatable {
  case idle
  case finished(title: String, exit: Int32, runDir: String?)
}

struct CommandRunner {
  var state: RunState = .idle
  var log = LogBuffer()
  var lastExit: Int32? = nil
  var lastRunDir: String? = nil
  var lastFailuresDir: String? = nil
  var lastReceiptPath: String? = nil

  mutating func resetLog() {
    log.lines.removeAll(keepingCapacity: true)
  }
}
```

> In PR2a, we keep runner simple: it stores logs and the last outcome. Streaming comes in PR2b.

---

## 2) Extend Key enum + readKey() for log view toggles

### Add to `Key` enum

Near your existing keys (up/down/enter/space/etc.) 

Add:

```swift
case toggleLogs   // 'l'
case escape       // ESC
case bottom       // '0'
```

### Extend `readKey()` mapping

Your `readKey` is here. 

Add:

```swift
case "l": return .toggleLogs
case "\u{1b}": return .escape      // ESC
case "0": return .bottom
```

---

## 3) Add new top-level state in `run()`

Right after you initialize mode flags and last paths , add:

```swift
var toast = ToastManager()
var runner = CommandRunner()
var showLogs = false
var logScroll = 0 // 0 = bottom
```

Also, at the start of each loop iteration (top of `while true`)  add:

```swift
toast.tick()
```

---

## 4) Modify `printScreen(...)` to render the toast and optionally render logs

### Change signature

Where you call `printScreen(...)` , add new params:

* `toastLine: toast.currentText`
* `showLogs: showLogs`
* `logLines: ...`
* `logScroll: logScroll`
* `runState: runner.state`

Example call change:

```swift
printScreen(
  title: "Operator Shell",
  items: items,
  selected: selected,
  // existing params...
  toastLine: toast.currentText,
  showLogs: showLogs,
  logLines: runner.log.window(count: /* computed */, scroll: logScroll),
  runState: runner.state
)
```

### Rendering behavior inside `printScreen`

Currently you print modes/keys at the bottom .
Insert toast line just above keys:

```swift
if let tl = toastLine {
  print(tl)
}
print(keysLine)
```

Now the big change: conditional body.

#### If `showLogs == true`:

* print a log header line
* print the log window lines
* print log-specific keys legend

Exact copy (as previously specified):

* Log header:

  * running not in PR2a; use finished/idle
  * For now:

    * `LOG  <last action title> (exit: X)` if finished
    * else `LOG  (no recent run)`

* Log keys line:

  ```
  keys: ↑↓ scroll   0 bottom   ESC back   q quit
  ```

#### If `showLogs == false`:

* do your existing menu rendering

This adds log view without changing execution yet.

---

## 5) Wire log view keys into the main loop

In `switch key`  add cases:

```swift
case .toggleLogs:
  showLogs.toggle()
  logScroll = 0
  toast.info(showLogs ? "Logs opened" : "Logs hidden", key: "logs_toggle")
  continue

case .escape:
  if showLogs {
    showLogs = false
    toast.info("Back to actions", key: "logs_back")
    continue
  }
  // else ignore or treat as quit (your call)
  continue

case .bottom:
  if showLogs {
    logScroll = 0
    toast.info("Jumped to bottom", key: "logs_bottom", ttl: 1.0)
    continue
  }
  // else ignore
  continue
```

### Scroll behavior (reusing up/down)

Modify `.up` / `.down` handling:

If `showLogs`:

* `.up` increases `logScroll` (bounded by total lines)
* `.down` decreases it

Else:

* keep your existing selection movement 

---

## 6) Capture output from existing `runAction` into the log (PR2a bridge)

Right now, `runAction` prints directly to stdout and waits for Enter. 

In PR2a, don’t fight that yet. Instead:

* Before calling `runAction`, write a few “bookend” lines into `runner.log`:

  * `> <command>`
  * `... running via legacy runner ...`
* After it returns, append:

  * `exit: N`
  * `runDir: ...` (if set)

Also set:

* `runner.state = .finished(title: action.title, exit: lastExit, runDir: lastRunDir)`
* `showLogs = true` (so after an action, the user sees output context even if legacy printed too)

Then toast success/failure as in the earlier mapping.

This makes logs “useful” immediately, even before streaming.

---

# PR2b — True streaming runner + remove cooked-mode prompt

This is where the magic happens.

## 1) Replace `runAction(...)` with an in-TUI runner

You currently have:

* confirmation prompt via `readLine()` 
* blocking `runProcess(...)` 
* “Press Enter to return…” 

PR2b removes all of that from the hot path.

### Extend RunState

Replace PR2a’s simplified RunState with:

```swift
enum RunState: Equatable {
  case idle
  case confirming(UI.RecommendedAction.Action)
  case running(title: String, startedAt: Date)
  case finished(title: String, exit: Int32, runDir: String?)
}
```

### Add transient process handle

In `CommandRunner`, store:

* `process: Process?`
* `pipe: Pipe?`
* `partialLineBuffer: String` (optional)

(You can keep Process references in runner or in a separate `StreamingProcess` wrapper.)

---

## 2) Add `startProcessStreaming(...)` helper

Create a helper in the same file or a new `ProcessStreaming.swift`:

```swift
func startProcessStreaming(
  launchPath: String,
  args: [String],
  onChunk: @escaping (String) -> Void,
  onExit: @escaping (Int32) -> Void
) throws -> Process {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: launchPath)
  p.arguments = args

  let pipe = Pipe()
  p.standardOutput = pipe
  p.standardError = pipe

  let handle = pipe.fileHandleForReading
  handle.readabilityHandler = { h in
    let data = h.availableData
    guard !data.isEmpty else { return }
    if let s = String(data: data, encoding: .utf8) {
      onChunk(s)
    }
  }

  p.terminationHandler = { proc in
    handle.readabilityHandler = nil
    onExit(proc.terminationStatus)
  }

  try p.run()
  return p
}
```

Then you do line splitting in the `onChunk` to append whole lines to `runner.log` (keeping a partial buffer between chunks).

---

## 3) Convert action execution to state transitions

### Where actions are launched today

* `.runRecommended` 
* `.enter` 
* `.selectNumber` 

Instead of calling `runAction`, do:

* If dangerous → `runner.state = .confirming(action)` and toast “confirmation required”
* Else → call `beginRun(action)`

### Add `beginRun(action)`

This:

1. clears log, opens log pane
2. appends a header line: `> wub ...`
3. starts streaming process
4. sets `runner.state = .running(...)`
5. on exit:

   * updates lastRunDir/receipt/failures (same as you do today after runProcess)
   * sets `runner.state = .finished(...)`
   * toasts success/fail
   * triggers readiness re-eval

---

## 4) Confirmation flow in the TUI (no `readLine()`)

When `runner.state == .confirming(action)`:

* render a confirmation prompt line above keys:

Exact text:

```
confirm: This action modifies studio state. Proceed?  (y)es / (n)o
```

In your key loop:

* if key maps to `y` or `n`:

  * `y` → `beginRun(action)`
  * `n` → `runner.state = .idle` and toast cancel message

To implement this, add `case "y": return .yes` / `case "n": return .no` into `readKey()` and handle them, but only when confirming.

---

## 5) Make the loop re-render while streaming

Right now, the UI updates only when a key is read. For streaming logs, you want periodic refresh.

Minimal option:

* Change `readKey()` to support a timeout (polling).
* If no key is pressed, return `.none` and continue the loop, re-rendering.

Implementation approach:

* Use `select()` on stdin fd with a timeout.
* If data available, read char; else return `.none`.

In the loop:

* on `.none`, just `continue` after printing screen (this makes the UI animate logs as they arrive).

---

## 6) Update keys legend depending on view + runner state

### When running

Add a small “busy” state:

* in header line 2 or 3:

  * `Run: active` or `Run: idle`
* or in log header:

  * `LOG  <title> (running)`

Keys in logs while running:

```
keys: ↑↓ scroll   0 bottom   ESC back   q quit
```

Optional:

* add `c` cancel (SIGINT) if you want.

---

# Exact “diff checklist” (so you can execute quickly)

### Files to touch (minimum)

* `tools/automation/swift-cli/Sources/StudioCore/OperatorShellCommand.swift` (main)
* optionally add:

  * `ToastManager.swift`
  * `CommandRunner.swift`
  * `ProcessStreaming.swift`

### PR2a changes

* [ ] Add ToastManager + show in `printScreen` near keys 
* [ ] Add log pane toggle + rendering + scroll
* [ ] Add `l`, ESC, `0` keys in `readKey` 
* [ ] After any action run, set `showLogs = true` and write summary lines to log

### PR2b changes

* [ ] Add `RunState.confirming/running/finished`
* [ ] Implement streaming Process runner
* [ ] Remove `readLine()` confirmation in `runAction`  (replace with TUI confirm)
* [ ] Remove “Press Enter to return…” 
* [ ] Add key polling so logs update without keypress
* [ ] Integrate toasts at state transitions (start/finish/cancel)

---

If you want the next “killer” detail after logs: once a run finishes, the log pane can show a single-line footer with clickable-ish affordances (keys) like:

* `o` open run folder
* `f` open failures folder
* `r` open receipt

You already track these paths (`lastRunDir`, `lastFailuresDir`, `lastReceiptPath`)  — adding a few keys makes recovery immediate for first-time users.
Continuing with the next “killer” increment: **in-log-pane affordances for recovery** (open run folder / failures / receipt), plus the exact key wiring points in your Operator Shell loop.

You already track these paths in `runAction`: `lastRunDir`, `lastFailuresDir`, `lastReceiptPath`  — so adding keys makes recovery immediate for first-time users.

---

# Add recovery keys: `o`, `f`, `r` (+ optional `c` cancel later)

## Key meanings (exact)

* `o` — open last run folder
* `f` — open failures folder (if present)
* `r` — open last receipt/report (if present)

### Toasts (exact)

* success:

  * `✓ Opened run folder`
  * `✓ Opened failures folder`
  * `✓ Opened receipt`
* blocked:

  * `! No run folder yet`
  * `! No failures folder for last run`
  * `! No receipt recorded yet`

---

# PR2a additions: wire keys and open paths (works even before streaming)

## 1) Extend `Key` enum + `readKey()`

### Add to `Key`

Near your existing key cases :

```swift
case openRunDir    // 'o'
case openFailures  // 'f'
case openReceipt   // 'r'
```

### Add mappings in `readKey()`

In the mapping switch :

```swift
case "o": return .openRunDir
case "f": return .openFailures
case "r": return .openReceipt
```

---

## 2) Add a tiny “open path” helper

Put near other helpers (bottom of file is fine):

```swift
@discardableResult
func openInFinder(_ path: String) -> Int32 {
  // macOS: `open`
  return runProcess("/usr/bin/open", args: [path])
}
```

If you want to be extra safe:

* if `path` is a file, `open` will open it in the default app
* if it’s a dir, Finder opens it

---

## 3) Handle these keys in your main switch loop

Add to the `switch key` inside `run()` :

```swift
case .openRunDir:
  guard let dir = lastRunDir else {
    toast.blocked("No run folder yet", key: "open_run_missing")
    continue
  }
  _ = openInFinder(dir)
  toast.success("Opened run folder", key: "open_run_ok")
  continue

case .openFailures:
  guard let dir = lastFailuresDir else {
    toast.blocked("No failures folder for last run", key: "open_fail_missing")
    continue
  }
  _ = openInFinder(dir)
  toast.success("Opened failures folder", key: "open_fail_ok")
  continue

case .openReceipt:
  guard let p = lastReceiptPath else {
    toast.blocked("No receipt recorded yet", key: "open_receipt_missing")
    continue
  }
  _ = openInFinder(p)
  toast.success("Opened receipt", key: "open_receipt_ok")
  continue
```

This is an immediate quality-of-life upgrade, even before you implement streaming.

---

# Update keys legend (exact copy)

## When menu view (not logs)

Add this to the end of your `keys:` line:

```
o open run   f failures   r receipt
```

Full suggested line:

```
keys: ↑↓ select   ENTER run   SPACE next   s SAFE/GUIDED   a GUIDED/ALL   v voice   o run   f fail   r receipt   ? help   q quit
```

If that’s too long for narrow terminals, use abbreviated labels at tight widths:

* `o run` `f fail` `r rec`

## When log pane is open

Use:

```
keys: ↑↓ scroll   0 bottom   ESC back   o run   f fail   r receipt   q quit
```

---

# PR2b: Make these keys even more helpful after streaming

Once you switch to streaming and stop leaving the TUI:

* On completion, append a **footer block** into the log buffer:

Example (exact):

```
— completed (exit: 1)
run: runs/2026-02-02_143012
failures: runs/2026-02-02_143012/failures
receipt: runs/2026-02-02_143012/receipt.json
```

Then your keys `o/f/r` feel perfectly “matched” to what the user sees.

---

# Optional next: “Open last report” (`p`) and “Copy path” (`c`)

If you have “last drift report” or “station status report” paths (you already compute station status report path for header printing in code elsewhere), add:

* `p` open last report
* `c` copy selected path (requires `pbcopy`)

Toasts:

* `✓ Copied path`

But `o/f/r` is the minimal “first-time recovery” set.

---

# Tight integration with readiness bar and recommended actions (how it feels)

After you implement the readiness bar and run an action:

* Toast: `! Action failed — see runs/…143012 for details`
* User presses `f`
* Finder opens failures folder
* Toast: `✓ Opened failures folder`
* They return, press `SPACE` to run next recommended step

This closes the loop for “I hit a failure and didn’t know how to recover.”

---

# Where this lands in your existing code (summary)

* `readKey()` additions at mapping site 
* `switch key` additions in main loop 
* Use paths already produced by your current run logic 

---

If you want the next continuation after this: implement **“in-TUI log pane without keypress refresh”** (stdin polling or a timer) so logs stream smoothly while a command runs. That’s the last piece that makes the Operator Shell feel like a real “creative OS cockpit” rather than a launcher.
Continuing with the last missing piece that makes the log pane feel *alive*: **refresh without keypress** (stdin polling / timed redraw), plus a clean way to do **cancel** (optional) and keep raw-mode input sane.

Everything below is designed to fit your current structure: a `while true { printScreen(); let key = readKey(); switch key { … } }` loop. 

---

## 1) The core problem

Right now the UI only redraws when a key is read. For streaming logs, you need the loop to wake up periodically even when no key is pressed.

The minimal fix is:

* make `readKey()` support a **timeout**
* return `.none` on timeout
* on `.none`, just continue the loop (which redraws)
* streaming process appends lines to `runner.log` asynchronously via readability handlers

This gives you a smooth “tail -f” experience inside the TUI.

---

## 2) Add a `.none` key and a timed `readKey(timeoutMs:)`

### A) Extend `Key`

Add:

```swift
case none
```

### B) Update the loop to use timed input

At the top of your `while true` loop, decide refresh rate:

* If `runner.state == .running` OR `showLogs == true`: poll fast (e.g., 100ms)
* Else: poll slower (e.g., 350ms) or block as today

Pseudo:

```swift
let timeoutMs: Int? = (runner.isRunning || showLogs) ? 100 : 350
let key = readKey(timeoutMs: timeoutMs)  // returns .none on timeout
```

### C) Implement `readKey(timeoutMs:)` using `select()`

On macOS, you can use `Darwin.select` on stdin’s file descriptor.

Here’s a working shape:

```swift
import Darwin

func readKey(timeoutMs: Int?) -> Key {
  // If timeoutMs is nil, do blocking getchar like today
  if timeoutMs == nil {
    return readKeyBlocking()
  }

  var readfds = fd_set()
  FD_ZERO(&readfds)
  FD_SET(STDIN_FILENO, &readfds)

  var tv = timeval(tv_sec: timeoutMs! / 1000,
                   tv_usec: (timeoutMs! % 1000) * 1000)

  let rc = select(STDIN_FILENO + 1, &readfds, nil, nil, &tv)
  if rc <= 0 {
    return .none
  }

  // stdin is ready: read 1 byte
  var buf: UInt8 = 0
  let n = read(STDIN_FILENO, &buf, 1)
  if n <= 0 { return .none }

  // Translate the char to your Key mapping
  return mapCharToKey(Character(UnicodeScalar(buf)))
}
```

You already have a `readKey()` that maps characters like `j/k`, arrows, `a/s/v`, SPACE, ENTER, etc. 
You’ll keep that mapping in `mapCharToKey`.

### D) Handle `.none` in the main switch

Add:

```swift
case .none:
  continue
```

This redraws every polling tick and shows streaming logs + toasts expiry (`toast.tick()`).

---

## 3) Make arrow keys work with `read()` (important detail)

Arrow keys come as escape sequences: `ESC [ A`, etc. Your current implementation likely reads a full line from stdin in raw mode already (you map some). 

With single-byte reads, you must implement a tiny state machine:

* if you read `\u{1b}` (ESC), peek for the next bytes with a very small timeout (like 5–10ms)
* read the rest of the sequence if present
* map to `.up/.down/.left/.right`

Practical approach:

* read `ESC`
* run a second `select()` with 10ms
* if next byte is `[`, read another byte and map `A/B/C/D`

If no extra bytes arrive, it was a plain ESC and maps to `.escape` (log view back).

This gives you:

* **ESC** works as “back”
* Arrow keys still work normally

---

## 4) Streaming logs: line splitting + partial buffer

Your process readability handler will deliver arbitrary chunks. You need to:

* append complete lines to `LogBuffer`
* keep partial last line in `runner.partialLine`

In `CommandRunner`, add:

```swift
var partial: String = ""
```

Then:

```swift
func onChunk(_ chunk: String) {
  var s = runner.partial + chunk
  let parts = s.split(separator: "\n", omittingEmptySubsequences: false)

  // If chunk ended with newline, last element is ""
  // Else last element is partial
  if s.hasSuffix("\n") {
    for p in parts.dropLast() { runner.log.append(String(p)) }
    runner.partial = ""
  } else {
    for p in parts.dropLast() { runner.log.append(String(p)) }
    runner.partial = String(parts.last ?? "")
  }
}
```

This is the difference between “logs smear together” vs “clean terminal lines.”

---

## 5) Optional but high value: cancel running command (`c`)

Once the UI is live while running, cancel becomes straightforward.

### A) Add key

* `c` = cancel run (only when running)

### B) How to cancel

If you store the `Process` instance in `runner.process`, you can send SIGINT:

```swift
if let p = runner.process {
  kill(p.processIdentifier, SIGINT)
}
```

### C) Exact toast copy

* On cancel request:

  ```
  ! Cancel requested — stopping run
  ```
* On exit due to cancel:

  ```
  • Run interrupted
  ```

### D) Key legend update (only when running)

In log pane while running:

```
keys: ↑↓ scroll   0 bottom   c cancel   ESC back   o run   f fail   r receipt   q quit
```

---

## 6) Keep “open run/fail/receipt” keys working during running

If run/fail/receipt directories are known only after completion, then:

* `o/f/r` should toast appropriately while running:

  * `! Run folder not available yet`
* Or, better: allocate run dir at start and stream logs to a file inside it.

### Best practice

When you start a run:

* create run directory immediately (even before launching process)
* set `runner.lastRunDir` right away
* stream logs also to `runs/<id>/operator_shell.log`

Then `o` always works, even mid-run.

Toast:

* `✓ Opened run folder`

---

## 7) Exact control flow in the loop (final shape)

At a high level:

1. `toast.tick()`
2. Evaluate `StudioState` (later)
3. `printScreen(...)` with header, toast, either menu or logs
4. `key = readKey(timeoutMs:)`
5. if confirming:

   * accept `y/n`
6. else:

   * normal key switch (navigate, run, toggle, open folders, toggle logs)

This keeps the Operator Shell conceptually simple: one loop, a couple of state flags.

---

## 8) How this interacts with the readiness bar + toasts (user experience)

* User hits SPACE
* Dangerous action → confirmation prompt in-place (no cooked mode)
* Press `y`
* Logs open automatically and stream
* Readiness bar remains visible at top
* On exit:

  * toast success/fail
  * readiness bar updates
  * `next:` updates
* User presses `f` if failed → failures folder opens

This is the full “cockpit” experience.

---

## 9) Small but crucial: don’t redraw too aggressively

Polling at 100ms is usually fine, but you should avoid unnecessary work:

* only compute expensive state (like scanning directories) every ~1s unless command just finished
* only redraw if:

  * toast changed
  * log buffer line count changed
  * selection changed
  * key pressed

You can implement a simple “dirty flag” later. Start with always redraw on `.none` while running; it’s acceptable for now.

---

If you want the next continuation after this: I’ll sketch the exact changes to your existing `readKey()` and arrow-sequence parsing (ESC handling), because that’s the only fiddly part when moving from blocking `getchar()` to `select()`-based polling.
Here’s the “fiddly but decisive” part: **how to implement `select()`-based polling** while still correctly handling **arrow keys** (ESC sequences) *and* preserving a clean mapping for `ESC` as “back.”

I’ll give you:

1. the **exact key parsing state machine**,
2. a **drop-in `readKey(timeoutMs:)`** replacement, and
3. the **minimal changes** to your existing `readKey()` mapping so you don’t regress behavior.

---

# 1) The key parsing problem (what changes when you poll)

When you move from blocking reads to polling single bytes:

* Arrow keys come in as multi-byte sequences:

  * Up: `ESC [ A`
  * Down: `ESC [ B`
  * Right: `ESC [ C`
  * Left: `ESC [ D`
* But you also want a plain `ESC` press to map to `.escape` for “back”.

So the algorithm must distinguish:

* “plain ESC” (user pressed ESC)
* “escape sequence” (arrow key or other terminal sequence)

---

# 2) Add new `Key` cases (minimal)

Extend your `Key` enum with:

```swift
case none
case escape
```

(You already had `escape` in your plan; add `none` for polling timeouts.)

---

# 3) A robust `readKey(timeoutMs:)` using `select()` + ESC parsing

Put this near the bottom where `readKey()` currently lives. Your current `readKey` uses a simple mapping on a character stream  — we’ll wrap that mapping, not replace it.

### Imports

At the top of the file (or in a small helper file):

```swift
import Darwin
```

### Helper: poll for 1 byte with timeout

```swift
@inline(__always)
func readByteWithTimeout(timeoutMs: Int) -> UInt8? {
  var readfds = fd_set()
  FD_ZERO(&readfds)
  FD_SET(STDIN_FILENO, &readfds)

  var tv = timeval(tv_sec: timeoutMs / 1000,
                   tv_usec: (timeoutMs % 1000) * 1000)

  let rc = select(STDIN_FILENO + 1, &readfds, nil, nil, &tv)
  if rc <= 0 { return nil }

  var b: UInt8 = 0
  let n = read(STDIN_FILENO, &b, 1)
  if n <= 0 { return nil }
  return b
}
```

### Helper: blocking read of 1 byte

```swift
@inline(__always)
func readByteBlocking() -> UInt8? {
  var b: UInt8 = 0
  let n = read(STDIN_FILENO, &b, 1)
  if n <= 0 { return nil }
  return b
}
```

### Key mapping function (reuse your current mapping)

Create a function that maps a single character to your existing `Key` cases:

```swift
func mapCharToKey(_ ch: Character) -> Key? {
  switch ch {
  case "q": return .quit
  case "j": return .down
  case "k": return .up
  case "\r", "\n": return .enter
  case " ": return .runRecommended
  case "s": return .toggleStudioMode
  case "a": return .toggleAll
  case "v": return .toggleVoiceMode
  case "l": return .toggleLogs
  case "0": return .bottom
  case "o": return .openRunDir
  case "f": return .openFailures
  case "r": return .openReceipt
  case "?": return .help
  default:
    // digits for voice numbers (optional)
    if let d = ch.wholeNumberValue { return .selectNumber(d) }
    return nil
  }
}
```

(You already map many of these in `readKey()`. This just relocates them into a pure mapping function so the polling input layer can call it.)

### The main function: `readKey(timeoutMs:)`

```swift
func readKey(timeoutMs: Int?) -> Key {
  // 1) Read first byte (blocking or timed)
  let first: UInt8?
  if let t = timeoutMs {
    first = readByteWithTimeout(timeoutMs: t)
    if first == nil { return .none }
  } else {
    first = readByteBlocking()
    if first == nil { return .none }
  }

  guard let b0 = first else { return .none }

  // 2) If not ESC, map normally
  if b0 != 0x1B { // ESC
    if let scalar = UnicodeScalar(b0) {
      return mapCharToKey(Character(scalar)) ?? .none
    }
    return .none
  }

  // 3) ESC: could be plain ESC, or an escape sequence
  // Peek next byte very briefly. If nothing arrives, treat as plain ESC.
  guard let b1 = readByteWithTimeout(timeoutMs: 12) else {
    return .escape
  }

  // Common CSI sequences start with '['
  if b1 == 0x5B { // '['
    // third byte determines arrow direction
    guard let b2 = readByteWithTimeout(timeoutMs: 12) else {
      return .escape
    }
    switch b2 {
    case 0x41: return .up    // 'A'
    case 0x42: return .down  // 'B'
    case 0x43: return .right // 'C' (if you support)
    case 0x44: return .left  // 'D' (if you support)
    default:
      return .escape
    }
  }

  // Some terminals send ESC O A/B for arrows (less common but possible)
  if b1 == 0x4F { // 'O'
    guard let b2 = readByteWithTimeout(timeoutMs: 12) else {
      return .escape
    }
    switch b2 {
    case 0x41: return .up
    case 0x42: return .down
    case 0x43: return .right
    case 0x44: return .left
    default:
      return .escape
    }
  }

  // Otherwise treat as ESC key (or unhandled sequence)
  return .escape
}
```

### Why the 12ms peeks work

* It’s short enough to not cause UI sluggishness on plain ESC.
* It’s long enough that terminal escape sequences arrive as a burst.

---

# 4) How to integrate into your loop (exact behavior)

In your main loop (`while true`) where you currently do:

```swift
let key = readKey()
```

Replace with:

```swift
let pollingMs: Int? = (showLogs || runnerIsRunning) ? 100 : 350
let key = readKey(timeoutMs: pollingMs)
```

Then add:

```swift
case .none:
  continue
```

This gives you:

* 10 FPS redraw while logs are streaming
* slower polling when idle (still responsive)
* and totally blocking behavior is no longer needed

---

# 5) Exact ESC semantics

With the above:

* Pressing ESC alone returns `.escape` reliably.
* Arrow keys return `.up/.down/.left/.right`.
* If you don’t want left/right, you can map them to `.none` or ignore.

Now in your `switch key`:

* if `showLogs == true` and `.escape` -> exit logs view
* else `.escape` can do nothing or be a “soft back” (your call)

The toast should trigger when ESC does something meaningful:

* “Back to actions”

---

# 6) Preserve raw-mode sanity

You’re already using `StdinRawMode` in `run()` .

With polling:

* keep raw mode enabled throughout
* don’t temporarily disable stdin for confirmation prompts
* avoid `readLine()` entirely

That’s what prevents the UI from dropping context and makes the log pane viable.

---

# 7) One more improvement: avoid rerendering if nothing changed (optional)

Once polling is in, you’ll redraw every 100ms while running. That’s fine, but you can reduce flicker by tracking “dirty” flags:

Mark dirty when:

* toast changes
* log line count changes
* selection changes
* recommended action changes
* runner state changes

If not dirty and key == `.none`, `continue` without printing. You can add this later.

---

# 8) Where this plugs into your existing file

* Replace your current `readKey()` implementation at the bottom (or keep it as `mapCharToKey` + polling wrapper). Your current function is at the bottom of `OperatorShellCommand.swift` .
* Your main loop is the `while true` in `run()` .

---

## Next continuation (if you want it)

The final step after polling + streaming is to unify:

* readiness evaluator
* recommended action
* “SPACE run next”
* and “gate transitions” → milestone success toasts

That makes the cockpit not just reactive, but *progressive*: every run advances A/S/I/F/R and tells you what changed.
Great — now we wire the whole cockpit together:

* **One shared `StudioState.evaluate()`**
* **Readiness bar A/S/I/F/R**
* **Deterministic recommended next action**
* **Gate transitions → milestone toasts**
* **Runner completion triggers re-eval + updates header + updates “next:”**

This is the piece that makes the shell feel like a coherent creative OS, not a collection of commands.

---

# 1) Build the shared evaluator: `StudioState.evaluate()`

## 1.1 Data model (small, stable)

```swift
enum Gate: CaseIterable { case anchors, sweep, index, artifacts, ready }

enum GateStatus: Equatable { case pass, pending, warn(String), fail(String) }

struct GateResult: Equatable {
  let gate: Gate
  let status: GateStatus
  let detailShort: String?   // e.g. "(3)" for artifacts
}

struct StudioStateSnapshot: Equatable {
  let gates: [GateResult]          // fixed order A,S,I,F,R
  let recommended: UI.RecommendedAction? // reuse your existing type if possible
  let recommendedIsVisible: Bool   // given SAFE/GUIDED/ALL view
  let blockers: [String]
  let warnings: [String]

  // Paths surfaced to UI + recovery keys
  let anchorsPackName: String?
  let anchorsPackPath: String?
  let lastRunDir: String?
  let lastFailuresDir: String?
  let lastReceiptPath: String?
}
```

**Key point:** keep the evaluator pure: it reads files/receipts and returns a snapshot. No printing, no prompts.

## 1.2 “Source of truth” inputs

You already have these in the repo and in OperatorShell:

* Anchors pack from `notes/LOCAL_CONFIG.json` (OperatorShell already loads it)
* Index from `checksums/index/artifact_index.v1.json` (wizard + dashboard logic already uses it)
* Drift report existence already used by dashboard logic to propose next steps (your `recommendedNextAction` reads latest drift report)
* Ready verify likely produces a receipt/report similar to others under `runs/<id>/...`

The evaluator should prefer **latest receipts/reports** rather than “did you run it in this session”.

---

# 2) Render the readiness bar from `StudioStateSnapshot`

## 2.1 Gate symbol mapping

* pass → `▣`
* pending → `▢`
* warn → `!`
* fail → `×`

## 2.2 Label + compact line (STATION)

Line 1 becomes:

```
STATION     A▣  S▢  I▣  F×(3)  R▢    next: <action>   [SPACE]
```

Where:

* `A` is `anchors`
* `S` is `sweep`
* `I` is `index`
* `F` is `artifacts` (optional counts)
* `R` is `ready`

**Counts rule**: if artifacts fail and you know missing/placeholder total `n`, show `F×(n)`.

---

# 3) Deterministic recommended next action mapping

This is crucial: “SPACE runs next” must feel consistent.

## 3.1 Policy

Pick the first gate in order that is **fail**, else first **pending** that is meaningful, else CLEARED.

Suggested mapping:

1. Anchors fail → recommend `anchors select` (or open UI with `--anchors-pack`)
2. Sweep fail/pending → recommend `sweep`
3. Index fail/pending → recommend `index build`
4. Artifacts fail → recommend `assets export-all`
5. Ready fail/pending → recommend `ready verify`
6. Else → no recommended action (CLEARED)

## 3.2 Visibility logic (SAFE/GUIDED/ALL)

* If recommended action is `danger == true` and mode is SAFE, mark `recommendedIsVisible = false`
* If mode is GUIDED and recommended action is not `isGuided`, mark false

Then the header and SPACE behavior can say:

* hidden in SAFE → press `s`
* not shown in GUIDED → press `a`

---

# 4) Gate transitions → milestone toasts (the “progress” feeling)

This is where the cockpit becomes *rewarding*.

## 4.1 Track previous snapshot

In `run()` loop state, keep:

```swift
var lastSnapshot: StudioStateSnapshot? = nil
```

After each eval, compare to last and emit milestone toasts when a gate changes.

## 4.2 Transition rules (exact)

On each loop:

1. `snapshot = evaluate()`
2. if `lastSnapshot != nil`:

   * for each gate, compare status
   * if it changed from non-pass → pass, toast milestone
   * if it changed from pass → fail, toast regression (rare but helpful)

## 4.3 Exact toast copy per gate

**Pass transitions:**

* Anchors: `✓ Anchors configured`
* Sweep: `✓ Sweep passed — no blocking modals detected`
* Index: `✓ Index built`
* Artifacts: `✓ Artifacts complete`
* Ready: `✓ Studio ready`

**Regression transitions (rare):**

* Anchors: `! Anchors unavailable — check anchors pack path`
* Sweep: `! Sweep blocked — modal or permission`
* Index: `! Index missing — rebuild required`
* Artifacts: `! Artifacts missing — export required`
* Ready: `! Studio not ready — verification failed`

**Throttle keys** should include the gate name, e.g. `gate_pass_anchors`, so repeated eval loops don’t spam.

---

# 5) Wire runner completion to evaluator + toasts

When a command finishes (in your streaming runner’s `onExit`):

1. update `lastRunDir / lastReceiptPath / lastFailuresDir` (you already do this today in `runAction`)
2. force `snapshot = evaluate()` immediately
3. compare to `lastSnapshot` and emit milestone toasts
4. update `lastSnapshot = snapshot`
5. keep logs visible; update header “next:” accordingly

This makes runs feel like they “advance the instrument”.

---

# 6) How to avoid expensive evaluation every 100ms

Once you poll keys every ~100ms while running, you don’t want to parse JSON + scan runs constantly.

## 6.1 Evaluate on a cadence + on events

* While running: evaluate at most once every 1.0s
* When a run finishes: evaluate immediately
* When anchors selection changes: evaluate immediately
* When user toggles SAFE/GUIDED/ALL: visibility changes, but the *state* doesn’t — you can avoid re-reading disk and only recompute visibility.

Implementation:

```swift
var lastEvalAt: Date = .distantPast
let evalInterval: TimeInterval = runnerIsRunning ? 1.0 : 0.5

if Date().timeIntervalSince(lastEvalAt) >= evalInterval || runnerJustFinished {
  snapshot = StudioState.evaluate(...)
  lastEvalAt = Date()
}
```

---

# 7) Add “Gate detail” line (optional but powerful)

When something fails, append a short inline note (if width allows), using the failing gate’s message:

Examples:

* Anchors fail: `(Anchors not set)`
* Sweep fail: `(Modal blocking detected)`
* Artifacts fail: `(3 missing)`

**Exact placement:** end of line 1 after `[SPACE]` (only if there’s space), or as line 4:

```
note: F× missing artifacts (3) — run export-all
```

This reinforces why “next” is what it is.

---

# 8) CLI parity: `wub check` and `wub preflight` should reuse the evaluator

Once `StudioState.evaluate()` exists:

## 8.1 `wub check`

* Print readiness bar in text
* Print blockers/warnings
* Print recommended next command
* Exit codes:

  * 0 CLEARED
  * 2 BLOCKED
  * 1 ERROR

## 8.2 `wub preflight`

* Run `check`
* If blocked:

  * print blocking reasons
  * print “Next:” commands
  * exit 3
* If `--auto`, run safe prerequisites:

  * if index missing → run index build (safe)
  * if sweep missing → run sweep (safe)
  * do **not** auto-run export-all unless `--allow-danger`

This means onboarding is deterministic whether you’re in CLI or TUI.

---

# 9) Concrete integration points in Operator Shell loop

You’ll place this near the top of the `while true` loop, before `printScreen(...)` :

```swift
toast.tick()

let snapshot = evaluator.evaluate(
  // pass in anchorsPack path if already loaded
  // pass in lastRunDir/receipt/failures if you want to surface them
)

if let prev = lastSnapshot {
  emitGateTransitionToasts(prev: prev, next: snapshot, toast: &toast)
}
lastSnapshot = snapshot

let rec = snapshot.recommended  // replaces existing recommendedNextAction call
```

Then `printScreen` uses:

* snapshot.gates for bar
* snapshot.recommended for “next”
* snapshot.anchorsPackName/path for line 3
* mode/view to decide “hidden in SAFE / not in GUIDED”

And SPACE uses snapshot visibility rules:

* if hidden → toast “press s”
* else run recommended

---

# 10) One more “killer” flourish: make SPACE do the right thing even when hidden

Behavior options:

### Conservative (recommended)

* If hidden in SAFE → toast + do nothing
* This preserves safety.

### Assistive (still safe if explicit)

* If hidden in SAFE, SPACE could offer:

  * `confirm: Next action is risky. Switch to GUIDED? (y/n)`
* That’s extremely friendly for first-time users.

If you do this, use the same in-TUI confirming system you built for danger prompts, and keep it explicit.

---

If you want the next continuation after this: I can propose an exact file breakdown for where `StudioState.evaluate()` should live in Swift CLI (which module, naming, JSON parsing helpers), and the *minimal JSON schemas* you should depend on so the evaluator doesn’t become brittle as receipts evolve.
Cool — next we make `StudioState.evaluate()` **real**, **robust**, and **not brittle** against evolving receipts.

I’ll cover:

1. **Where it should live** in the Swift CLI modules
2. **What files/schemas it should depend on** (minimal surface area)
3. **How to find “latest” receipts reliably**
4. **A concrete evaluator implementation outline** (with parsing strategy)
5. **How `wub check` / `wub preflight` consume it** without duplication

---

# 1) Where `StudioState.evaluate()` should live

### Goal

* Shared by: Operator Shell, `wub check`, `wub preflight`, wizard, future UI
* Pure: no terminal I/O, no prompts
* Small dependency footprint

### Recommended location

Create a new file under the same module that owns Operator Shell (looks like `StudioCore`):

```
tools/automation/swift-cli/Sources/StudioCore/StudioStateEvaluator.swift
```

And optionally split types:

```
Sources/StudioCore/StudioStateTypes.swift
Sources/StudioCore/StudioStateEvaluator.swift
Sources/StudioCore/StudioStateRendering.swift   // for bar rendering (optional)
```

This avoids contaminating `OperatorShellCommand.swift` with domain logic.

---

# 2) Minimal “schema dependencies” (avoid brittleness)

The evaluator should **not** depend on deep internal receipt formats unless necessary. Prefer:

* existence checks
* small, stable keys
* “good enough” heuristics (with graceful `pending`)

## 2.1 Anchors Gate (A)

**Inputs**

* `notes/LOCAL_CONFIG.json` → `anchorsPack` path (Operator Shell already loads this)
  **Rule**
* PASS if `anchorsPack` exists and directory exists
* FAIL if missing / nonexistent

No other schema required.

## 2.2 Index Gate (I) + Artifacts Gate (F)

**Inputs**

* `checksums/index/artifact_index.v1.json` (already referenced by wizard docs and used to detect pending artifacts)
  **Minimum schema to depend on**
* A top-level list/collection of artifacts that can be classified into:

  * present vs missing
  * placeholder vs real

If that file is complex, define a *very small* parsing strategy:

* decode as generic JSON (`[String: Any]` or `JSONValue`)
* look for stable fields like:

  * `missing: true`
  * `placeholder: true`
  * `status: "missing"/"placeholder"/"present"`
* If none found, fall back to:

  * file exists → Index PASS, Artifacts PENDING (warn: “unknown format”)

**Rules**

* Index PASS if file exists and JSON parses
* Index FAIL if missing/unreadable
* Artifacts FAIL if missingCount + placeholderCount > 0
* Artifacts PASS if both are 0
* Artifacts WARN/PENDING if schema unknown

> This keeps the evaluator resilient if you refactor the index format.

## 2.3 Sweep Gate (S)

**Inputs**

* Latest sweep receipt or report in `runs/<id>/...`

**Minimum schema**
Try to avoid parsing deep details; depend on:

* exit code recorded in receipt OR a simple `result: "pass"/"fail"`

If unavailable:

* If there is a recent run directory with a known sweep marker filename, treat as PASS/PENDING based on timestamp.

**Rules**

* PASS if last sweep indicates pass
* FAIL if last sweep indicates fail
* PENDING if never run / can’t determine

## 2.4 Ready Gate (R)

Same strategy as Sweep:

* find latest ready-verify receipt
* read minimal pass/fail signal

**Rules**

* PASS if latest verify pass
* FAIL if latest verify fail
* PENDING if never run

---

# 3) How to find “latest” run artifacts reliably

You already rely on run directories under `runs/` (and your code tracks `lastRunDir`). 

## 3.1 Don’t trust directory naming alone

Even if names have timestamps, always prefer filesystem metadata:

* `FileManager.attributesOfItem(atPath:)` → `.modificationDate`

## 3.2 Create a tiny “run locator” helper

### API shape

```swift
struct RunLocator {
  let runsRoot: URL

  func latestRunDirs(limit: Int = 30) -> [URL]
  func latestReceipt(matching patterns: [String]) -> URL?
  func latestReport(matching patterns: [String]) -> URL?
}
```

### Pattern strategy (stable + flexible)

Use filename substring patterns rather than exact names:

* sweep: `["sweep", "dubsweeper"]`
* ready: `["ready", "verify"]`
* drift: `["drift_report"]`
* station: `["station_status_report"]`

This lets you rename files without breaking evaluation.

---

# 4) Concrete evaluator outline (what it returns)

## 4.1 Types (exact)

```swift
enum Gate: String, CaseIterable { case anchors = "A", sweep = "S", index = "I", artifacts = "F", ready = "R" }

enum GateStatus: Equatable {
  case pass
  case pending
  case warn(String) // non-blocking detail
  case fail(String) // blocking detail
}

struct GateResult: Equatable {
  let gate: Gate
  let status: GateStatus
  let detailShort: String? // e.g. "(3)" or "(stale)"
}

struct StudioStateSnapshot: Equatable {
  let gates: [GateResult]
  let blockers: [String]
  let warnings: [String]

  // For header
  let anchorsPackName: String?
  let anchorsPackPath: String?

  // For recovery keys
  let lastRunDir: String?
  let lastFailuresDir: String?
  let lastReceiptPath: String?

  // Recommended “next” expressed as a command string + metadata
  let recommended: RecommendedNext?
}

struct RecommendedNext: Equatable {
  let title: String          // e.g. "Assets: export ALL"
  let command: [String]      // ["wub", "assets", "export-all", ...]
  let danger: Bool
  let guided: Bool
  let reason: String         // "Missing artifacts: 3"
}
```

This snapshot is UI-agnostic and CLI-friendly.

---

## 4.2 Evaluate flow (deterministic)

```swift
func evaluate() -> StudioStateSnapshot {
  let anchors = evaluateAnchors()
  let index = evaluateIndex()
  let artifacts = evaluateArtifacts(using: index)
  let sweep = evaluateSweep()
  let ready = evaluateReady()

  let gates = [anchors, sweep, index, artifacts, ready]
  let (blockers, warnings) = deriveBlockersAndWarnings(gates)
  let next = recommendNext(gates)

  return StudioStateSnapshot(...)

}
```

### Recommend Next (policy)

* earliest FAIL gate → its recommended action
* else earliest PENDING gate (only if it matters)
* else nil

Mapping:

* Anchors FAIL → `wub anchors select` (or `wub ui --anchors-pack ...`)
* Sweep FAIL/PENDING → `wub sweep --modal-test detect --allow-ocr-fallback` 
* Index FAIL/PENDING → `wub index build` 
* Artifacts FAIL → `wub assets export-all --anchors-pack <pack> --overwrite` 
* Ready FAIL/PENDING → `wub ready verify` 

---

# 5) How to parse the artifact index without coupling

## 5.1 Prefer tolerant parsing via a “JSONValue” enum

This avoids schema lock-in.

```swift
enum JSONValue: Decodable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null
}
```

Then you can walk it and count “missing/placeholder” using heuristics:

* any object with `"missing": true`
* or `"status": "missing"`
* similarly for placeholder

If the heuristics yield 0 but structure is unknown:

* return `GateStatus.warn("Index format unknown")` and treat artifacts as pending

## 5.2 Persist the exact counts you find

Artifacts gate:

* `detailShort = "(3)"`

---

# 6) “Staleness” and WARNs (optional but very useful)

First-time users often run something once and then later the system is “unknown.” You can add a staleness policy:

* Sweep PASS only if latest sweep was within, say, **15 minutes**; else `warn("stale")` and `detailShort="(stale)"`.
* Ready PASS within **60 minutes**; else warn stale.

This keeps the readiness bar honest without blocking.

---

# 7) CLI integration: `wub check` + `wub preflight`

## 7.1 `wub check`

* Calls evaluator
* Prints:

  * readiness bar line
  * blockers (if any)
  * warnings (if any)
  * recommended next command

Exit:

* 0 if no FAIL gates
* 2 if any FAIL gate
* 1 on internal error (e.g., cannot read config root)

## 7.2 `wub preflight`

* Calls evaluator
* If blocked:

  * print same as check
  * exit 3
* If `--auto`:

  * If index missing → run index build
  * If sweep pending/stale → run sweep
  * Re-eval
* Only run dangerous steps if `--allow-danger` (prompt or flag)

This makes `make onboard` a real contract.

---

# 8) Operator Shell integration: milestone toasts from gate transitions

Once you have snapshots, you can emit milestone toasts in a single function:

```swift
func emitGateTransitionToasts(prev: StudioStateSnapshot, next: StudioStateSnapshot, toast: inout ToastManager)
```

Rules:

* if gate transitions to PASS → milestone toast (Anchors configured, Index built, Artifacts complete, Studio ready)
* if transitions to FAIL → regression toast

This creates the “progress feeling” users need.

---

# 9) Practical implementation order (fastest path)

1. Add evaluator that supports **Anchors, Index, Artifacts** first
   (This already fixes the biggest onboarding confusion: “why export-all?”)
2. Add Sweep and Ready using minimal heuristics (pass/fail based on existence + last exit)
3. Add staleness WARNs
4. Wire to Operator Shell header + SPACE
5. Add `wub check`
6. Add `wub preflight` and `make onboard`

---

If you want, next I can provide **exact command-line strings** (arguments) as they appear in your menu today for sweep/index/export-all/ready, and a stub implementation for `RunLocator.latestReceipt(...)` that searches `runs/` efficiently without scanning thousands of directories.
Absolutely — here are (A) the **exact command strings** you should treat as canonical “next actions” (matching what the Operator Shell already runs today), and (B) a **stubbed but production-grade `RunLocator`** that finds the latest sweep/ready receipts/reports efficiently without scanning the world.

I’ll also show how to plug `RunLocator` into `StudioState.evaluate()` so the evaluator stays **tolerant** and **not brittle**.

---

## A) Canonical command strings (match Operator Shell behavior)

These should be the default mappings for `recommended next` and for `wub preflight --auto` steps.

### Sweep (modal guard)

```bash
wub sweep --modal-test detect --allow-ocr-fallback
```

### Index

```bash
wub index build
```

(And status, if you want it in `check` output)

```bash
wub index status
```

### Assets export (dangerous; completes Artifacts gate)

This is the big one for first-time setup and should be the primary “Artifacts fail” remediation:

```bash
wub assets export-all --anchors-pack <ANCHORS_PACK_PATH> --overwrite
```

### Drift

If you include drift in your “advanced” readiness, keep it separate (I recommend it as a WARN gate initially, not part of A/S/I/F/R):

```bash
wub drift check
wub drift plan
wub drift fix   # dangerous
```

### Ready verify (operational gate)

```bash
wub ready verify
```

### Repair / Station certify (advanced; often dangerous)

```bash
wub repair run
wub ready station-certify
```

### New: Anchors selection (first-run)

You want a stable, human command:

```bash
wub anchors select
```

If you don’t want to add a full selector command yet, fallback is:

```bash
wub ui --anchors-pack <ANCHORS_PACK_PATH>
```

…but adding `wub anchors select` is worth it because it becomes the “A gate” remediation everywhere.

---

## B) `RunLocator`: fast “latest receipt/report” without brittle naming

### Design goals

* Prefer filesystem modification time.
* Search only the most recent N run directories (default 30–80).
* Match by **substring patterns** (e.g., `["sweep","dubsweeper"]`), not exact filenames.
* Return a URL to:

  * a receipt JSON
  * a report JSON
  * or any artifact you want to inspect

### Swift implementation (drop-in)

```swift
import Foundation

struct RunLocator {
  let runsRoot: URL
  let fm = FileManager.default

  // Tune: how many recent run dirs to consider
  var maxRunsToScan: Int = 60

  // MARK: - Public API

  func latestArtifact(matchingAny patterns: [String]) -> URL? {
    for runDir in latestRunDirs(limit: maxRunsToScan) {
      if let u = firstMatch(in: runDir, patterns: patterns) {
        return u
      }
    }
    return nil
  }

  func latestReceipt(matchingAny patterns: [String]) -> URL? {
    // Prefer files that "look like receipts"
    let receiptish = patterns + ["receipt", "Receipt", ".receipt", "receipt.json"]
    return latestArtifact(matchingAny: receiptish)
  }

  func latestReport(matchingAny patterns: [String]) -> URL? {
    // Prefer files that "look like reports"
    let reportish = patterns + ["report", "Report", "_report", "report.json"]
    return latestArtifact(matchingAny: reportish)
  }

  func latestRunDirs(limit: Int) -> [URL] {
    guard let items = try? fm.contentsOfDirectory(
      at: runsRoot,
      includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
      options: [.skipsHiddenFiles]
    ) else { return [] }

    // Filter to directories
    let dirs: [(url: URL, mtime: Date)] = items.compactMap { u in
      guard (try? u.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
      let mtime = (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return (u, mtime)
    }

    // Sort newest-first
    let sorted = dirs.sorted { $0.mtime > $1.mtime }.prefix(limit).map { $0.url }
    return Array(sorted)
  }

  // MARK: - Internals

  private func firstMatch(in runDir: URL, patterns: [String]) -> URL? {
    // Shallow scan of the run directory (no recursion) is often enough.
    // If you have nested receipts, add a lightweight recursive option.
    guard let files = try? fm.contentsOfDirectory(
      at: runDir,
      includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
      options: [.skipsHiddenFiles]
    ) else { return nil }

    // Filter regular files
    let regular: [(url: URL, mtime: Date)] = files.compactMap { u in
      guard (try? u.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return nil }
      let mtime = (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
      return (u, mtime)
    }

    // Prefer newest matching file in that run dir
    let loweredPatterns = patterns.map { $0.lowercased() }
    let matches = regular.filter { item in
      let name = item.url.lastPathComponent.lowercased()
      return loweredPatterns.contains(where: { name.contains($0) })
    }

    return matches.sorted { $0.mtime > $1.mtime }.first?.url
  }
}
```

### If receipts are nested in subfolders

Add an optional recursive scan limited by depth:

```swift
func firstMatchRecursive(in dir: URL, patterns: [String], maxDepth: Int = 3) -> URL? { /* ... */ }
```

But I’d start shallow; it’s faster and usually sufficient if your run output layout is reasonably flat.

---

## C) How `StudioState.evaluate()` uses `RunLocator` (minimal coupling)

### Typical patterns

* Sweep: `["sweep", "dubsweeper"]`
* Ready verify: `["ready", "verify"]`
* Drift report (optional): `["drift_report", "drift"]`
* Station status (optional): `["station_status_report", "station_status"]`

### Example usage inside evaluator

```swift
let locator = RunLocator(runsRoot: URL(fileURLWithPath: "runs"))

let sweepReceipt = locator.latestReceipt(matchingAny: ["sweep", "dubsweeper"])
let readyReceipt = locator.latestReceipt(matchingAny: ["ready", "verify"])
```

### Extract pass/fail without brittle schema

Start with a tolerant approach:

* If receipt JSON has a top-level `status` field (`"pass"|"fail"`) → use it
* Else if it has `ok: true/false` → use it
* Else if it has `exitCode` or `exit_code` → `0` pass, else fail
* Else: unknown → pending/warn

That’s enough for first-time UX.

---

## D) One more efficiency trick: don’t scan runs on every tick

With polling at 100ms while streaming logs, do:

* evaluate receipts at most once per second while running
* always evaluate immediately when a run finishes

This keeps the UI snappy.

---

## E) Sanity defaults for patterns and “latest run” pointers

In the Operator Shell:

* Maintain `lastRunDir / lastReceiptPath / lastFailuresDir` from the runner (authoritative for the current session)
* Use `RunLocator` only when those are missing or stale

That way:

* post-run: zero scanning
* fresh boot: evaluator still works

---

If you want the next step: I can give you a compact, tolerant `ReceiptSignal` parser (reads JSON as `Any` / `JSONValue` and returns `.pass/.fail/.unknown`), and show exactly how to convert that into `S` and `R` gate statuses with staleness warnings.
Here’s the next building block: a **tolerant `ReceiptSignal` parser** that turns “whatever JSON we have” into **PASS / FAIL / UNKNOWN**, plus a clean way to map that into **Sweep (S)** and **Ready (R)** gates with **staleness WARNs**.

This is designed to be **schema-light** and resilient as receipts evolve.

---

# 1) `ReceiptSignal`: minimal, tolerant, resilient

## 1.1 Types

```swift
enum ReceiptSignal: Equatable {
  case pass
  case fail(reason: String?)
  case unknown(reason: String?)
}

struct ReceiptObservation: Equatable {
  let url: URL
  let signal: ReceiptSignal
  let modifiedAt: Date?
}
```

## 1.2 Parsing strategy (in order)

We’ll interpret as PASS/FAIL using these common patterns:

1. `status: "pass" | "ok" | "success"` or `"fail" | "error"`
2. `result: "pass"/"fail"` or `"ok"/"error"`
3. `ok: true/false`, `success: true/false`, `passed: true/false`
4. `exitCode / exit_code / terminationStatus` where `0` = pass
5. If nothing matches → `unknown`

## 1.3 Implementation using `JSONSerialization` (fast and tolerant)

```swift
import Foundation

func readReceiptSignal(from url: URL) -> ReceiptObservation {
  let fm = FileManager.default
  let mtime: Date? = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)

  guard
    let data = try? Data(contentsOf: url),
    let obj = try? JSONSerialization.jsonObject(with: data),
    let dict = obj as? [String: Any]
  else {
    return ReceiptObservation(url: url, signal: .unknown(reason: "unreadable"), modifiedAt: mtime)
  }

  // Helpers
  func str(_ key: String) -> String? { dict[key] as? String }
  func bool(_ key: String) -> Bool? { dict[key] as? Bool }
  func int(_ key: String) -> Int? {
    if let n = dict[key] as? Int { return n }
    if let n = dict[key] as? Double { return Int(n) }
    if let s = dict[key] as? String, let n = Int(s) { return n }
    return nil
  }

  func normalize(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

  // 1) status/result string fields
  for k in ["status", "result", "outcome"] {
    if let v = str(k).map(normalize) {
      if ["pass", "passed", "ok", "success"].contains(v) { return .init(url: url, signal: .pass, modifiedAt: mtime) }
      if ["fail", "failed", "error"].contains(v) { return .init(url: url, signal: .fail(reason: "\(k)=\(v)"), modifiedAt: mtime) }
    }
  }

  // 2) boolean flags
  for k in ["ok", "success", "passed"] {
    if let v = bool(k) {
      return .init(url: url, signal: v ? .pass : .fail(reason: "\(k)=false"), modifiedAt: mtime)
    }
  }

  // 3) exit codes
  for k in ["exitCode", "exit_code", "terminationStatus"] {
    if let v = int(k) {
      return .init(url: url, signal: (v == 0 ? .pass : .fail(reason: "\(k)=\(v)")), modifiedAt: mtime)
    }
  }

  return .init(url: url, signal: .unknown(reason: "no recognized fields"), modifiedAt: mtime)
}
```

This avoids coupling to any specific receipt schema. If you later standardize receipts, this still works.

---

# 2) Turn `ReceiptObservation` into gate status with staleness

## 2.1 Staleness policy (practical defaults)

* Sweep: **stale after 15 minutes**
* Ready verify: **stale after 60 minutes**

Stale should be `warn("stale")`, not fail. Fail is for explicit failures.

```swift
func gateStatusFromReceipt(
  _ obs: ReceiptObservation?,
  staleAfter seconds: TimeInterval,
  gateName: String
) -> (GateStatus, String?) {
  guard let obs else {
    return (.pending, nil)
  }

  let isStale: Bool = {
    guard let m = obs.modifiedAt else { return false }
    return Date().timeIntervalSince(m) > seconds
  }()

  switch obs.signal {
  case .pass:
    if isStale {
      return (.warn("\(gateName) stale"), "(stale)")
    }
    return (.pass, nil)

  case .fail(let reason):
    return (.fail(reason ?? "\(gateName) failed"), nil)

  case .unknown(let reason):
    // Unknown is a soft WARN, not a hard FAIL.
    return (.warn(reason ?? "\(gateName) unknown"), nil)
  }
}
```

---

# 3) Use `RunLocator` to find receipts for Sweep and Ready

Use patterns, not exact file names:

* Sweep patterns: `["sweep", "dubsweeper"]`
* Ready patterns: `["ready", "verify"]`

```swift
let locator = RunLocator(runsRoot: URL(fileURLWithPath: "runs"))

let sweepURL = locator.latestReceipt(matchingAny: ["sweep", "dubsweeper"])
let readyURL = locator.latestReceipt(matchingAny: ["ready", "verify"])

let sweepObs = sweepURL.map { readReceiptSignal(from: $0) }
let readyObs = readyURL.map { readReceiptSignal(from: $0) }

let (sweepStatus, sweepDetail) = gateStatusFromReceipt(sweepObs, staleAfter: 15*60, gateName: "Sweep")
let (readyStatus, readyDetail) = gateStatusFromReceipt(readyObs, staleAfter: 60*60, gateName: "Ready")
```

Then build gate results:

```swift
GateResult(gate: .sweep, status: sweepStatus, detailShort: sweepDetail)
GateResult(gate: .ready, status: readyStatus, detailShort: readyDetail)
```

---

# 4) Make `S` and `R` drive deterministic “next action”

If:

* Sweep is `.pending` or `.warn("stale")`: recommend sweep
* Sweep is `.fail`: recommend sweep
* Ready is `.pending`: recommend ready verify
* Ready is `.fail`: recommend ready verify first; later you can recommend `repair run` if repeated fails

This matches the “first failing gate decides next” policy.

---

# 5) Efficient scanning: keep it cheap during polling

When your TUI is polling at ~100ms while streaming logs, don’t run `RunLocator` every tick.

Add a cached evaluation cadence:

* If runner is running: re-eval at most once per second
* If runner finished: re-eval immediately
* If no activity: 0.5s cadence is fine

Also: if you already have `lastReceiptPath` from the current run, you can use that directly instead of scanning runs.

---

# 6) Optional improvement: prefer “receipt file in last run dir”

Best UX:

* When a command finishes, you already know the run dir (you set `lastRunDir`) and you can discover sweep/ready receipts inside it first.
* Only fall back to global `runs/` scanning if you have no current run context.

This yields:

* deterministic “what just happened” evaluation
* minimal filesystem work

---

# 7) What to print in `wub check` (now that S and R exist)

A good `wub check` output now becomes:

* readiness bar
* blockers (FAIL gates)
* warnings (WARN gates like stale)
* recommended next action

Example:

```
STATION  A▣  S!(stale)  I▣  F▣  R▢
warnings:
- Sweep stale (last run > 15m)

next:
  wub sweep --modal-test detect --allow-ocr-fallback
```

---

If you want the next continuation: I can provide the **artifact index tolerant parser** (counts missing + placeholder without locking to schema) so `F×(n)` is always correct and the export-all recommendation becomes fully deterministic.
Here’s the **tolerant artifact-index parser** you need to make `F×(n)` reliable without hard-coupling to the current `artifact_index.v1.json` schema.

The key idea: parse JSON generically, then **walk the tree** looking for “missing” and “placeholder” signals using a small set of heuristics. If the schema changes, this still works.

---

# 1) What we want out of the index

From `checksums/index/artifact_index.v1.json` we need only:

* `missingCount`
* `placeholderCount`
* (optional) `totalCount` (for nicer UX)
* (optional) a short “top reasons” list (for explain panel)

That’s it.

---

# 2) Generic JSON type (schema-agnostic)

Use a lightweight recursive enum:

```swift
enum JSONValue: Decodable {
  case object([String: JSONValue])
  case array([JSONValue])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  init(from decoder: Decoder) throws {
    let c = try decoder.singleValueContainer()
    if c.decodeNil() { self = .null; return }
    if let v = try? c.decode(Bool.self) { self = .bool(v); return }
    if let v = try? c.decode(Double.self) { self = .number(v); return }
    if let v = try? c.decode(String.self) { self = .string(v); return }
    if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
    if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
    throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON")
  }
}
```

Then decode:

```swift
let root = try JSONDecoder().decode(JSONValue.self, from: data)
```

---

# 3) Heuristics to detect “missing” and “placeholder”

We look for **artifact-ish objects**, and then check a few stable patterns:

### Missing signals (any of these)

* `"missing": true`
* `"status": "missing"`
* `"state": "missing"`
* `"present": false`
* `"exists": false`
* `"isMissing": true`

### Placeholder signals

* `"placeholder": true`
* `"status": "placeholder"`
* `"isPlaceholder": true`
* `"kind": "placeholder"`

### “Artifact-ish object” detection

We only count objects that look like a discrete artifact record. We can define that as:

* object contains one of: `"id"`, `"name"`, `"artifact"`, `"path"`, `"key"`, `"checksum"`
* OR it has both `"status"` and something identifier-like

This avoids counting some random nested structure.

---

# 4) Implementation: walk and count

```swift
struct ArtifactIndexSummary: Equatable {
  var totalArtifacts: Int = 0
  var missing: Int = 0
  var placeholder: Int = 0
  var unknownFormat: Bool = false
}

func loadArtifactIndexSummary(at url: URL) -> ArtifactIndexSummary {
  guard let data = try? Data(contentsOf: url) else {
    return ArtifactIndexSummary(totalArtifacts: 0, missing: 0, placeholder: 0, unknownFormat: true)
  }
  guard let root = try? JSONDecoder().decode(JSONValue.self, from: data) else {
    return ArtifactIndexSummary(totalArtifacts: 0, missing: 0, placeholder: 0, unknownFormat: true)
  }

  var s = ArtifactIndexSummary()
  var foundAnyArtifactRecords = false

  func asString(_ v: JSONValue) -> String? {
    if case .string(let x) = v { return x }
    return nil
  }
  func asBool(_ v: JSONValue) -> Bool? {
    if case .bool(let x) = v { return x }
    return nil
  }

  func normalized(_ x: String) -> String { x.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

  func objectLooksLikeArtifact(_ obj: [String: JSONValue]) -> Bool {
    // Identifier-like keys
    let keys = Set(obj.keys.map { $0.lowercased() })
    let idish = ["id", "name", "artifact", "path", "key", "checksum", "sha", "filename"]
    if keys.contains(where: { idish.contains($0) }) { return true }

    // status + any idish
    if keys.contains("status") && keys.contains(where: { idish.contains($0) }) { return true }

    return false
  }

  func isMissing(_ obj: [String: JSONValue]) -> Bool {
    // Boolean flags
    let boolKeys = ["missing", "ismissing"]
    for k in boolKeys {
      if let v = obj.first(where: { $0.key.lowercased() == k })?.value,
         asBool(v) == true { return true }
    }
    // present/exists false
    for k in ["present", "exists"] {
      if let v = obj.first(where: { $0.key.lowercased() == k })?.value,
         asBool(v) == false { return true }
    }
    // status/state strings
    for k in ["status", "state"] {
      if let v = obj.first(where: { $0.key.lowercased() == k })?.value,
         let sv = asString(v).map(normalized),
         ["missing", "absent", "not_found"].contains(sv) { return true }
    }
    return false
  }

  func isPlaceholder(_ obj: [String: JSONValue]) -> Bool {
    for k in ["placeholder", "isplaceholder"] {
      if let v = obj.first(where: { $0.key.lowercased() == k })?.value,
         asBool(v) == true { return true }
    }
    for k in ["status", "kind", "type"] {
      if let v = obj.first(where: { $0.key.lowercased() == k })?.value,
         let sv = asString(v).map(normalized),
         ["placeholder", "stub", "template"].contains(sv) { return true }
    }
    return false
  }

  func walk(_ v: JSONValue) {
    switch v {
    case .array(let a):
      for x in a { walk(x) }

    case .object(let o):
      // Count artifact-like objects
      if objectLooksLikeArtifact(o) {
        foundAnyArtifactRecords = true
        s.totalArtifacts += 1
        if isMissing(o) { s.missing += 1 }
        if isPlaceholder(o) { s.placeholder += 1 }
      }
      // Recurse into all children
      for (_, child) in o { walk(child) }

    default:
      break
    }
  }

  walk(root)

  if !foundAnyArtifactRecords {
    s.unknownFormat = true
  }
  return s
}
```

### Notes

* This will “overcount” if the index contains nested artifact objects (rare). If you see that, add a safeguard: only count objects at certain depths or only within an `"artifacts"` array if present (still schema-tolerant).
* You can tighten `objectLooksLikeArtifact` if you get false positives.

---

# 5) Map this into the Index + Artifacts gates

## Index gate (I)

* PASS if file exists and JSON decodes
* FAIL if missing/unreadable
* WARN if decodes but `unknownFormat == true` (still treat Index as PASS but Artifacts as WARN)

## Artifacts gate (F)

* FAIL if `missing + placeholder > 0`
* PASS if both are 0
* WARN if `unknownFormat == true` (can’t confirm completeness)

Example:

```swift
func evaluateIndexAndArtifacts(indexURL: URL?) -> (GateResult, GateResult, ArtifactIndexSummary?) {
  guard let url = indexURL else {
    return (
      GateResult(gate: .index, status: .fail("Index missing"), detailShort: nil),
      GateResult(gate: .artifacts, status: .pending, detailShort: nil),
      nil
    )
  }

  let summary = loadArtifactIndexSummary(at: url)

  // Index status
  let indexStatus: GateStatus = summary.unknownFormat ? .warn("Index format unknown") : .pass
  let indexGate = GateResult(gate: .index, status: indexStatus, detailShort: summary.unknownFormat ? "(?)" : nil)

  // Artifacts status
  let totalBad = summary.missing + summary.placeholder
  let artifactsStatus: GateStatus
  let detail: String?

  if summary.unknownFormat {
    artifactsStatus = .warn("Artifacts unknown")
    detail = nil
  } else if totalBad > 0 {
    artifactsStatus = .fail("Missing/placeholder artifacts: \(totalBad)")
    detail = "(\(totalBad))"
  } else {
    artifactsStatus = .pass
    detail = nil
  }

  let artifactsGate = GateResult(gate: .artifacts, status: artifactsStatus, detailShort: detail)
  return (indexGate, artifactsGate, summary)
}
```

---

# 6) Deterministic “next action” for `F×(n)`

If Artifacts FAIL and anchors pack is set:

```bash
wub assets export-all --anchors-pack <path> --overwrite
```

If anchors pack missing, Artifacts should not recommend export; Anchors gate will be earlier and will win.

If `unknownFormat == true`, don’t aggressively recommend export-all. Instead:

* recommend `wub index build` (safe) or `wub index status` (safe)
* or show a WARN: “Artifacts unknown; run index build”

---

# 7) UX tie-in: Explain panel + readiness bar

Once you have `summary`, you can show meaningful details in the Operator Shell explain pane when Artifacts is failing:

* `Missing: X`
* `Placeholder: Y`
* `Total: Z` (if you choose to compute it)

And in readiness bar:

* `F×(X+Y)` exactly.

---

# 8) One more guardrail: avoid “schema drift” killing onboarding

If `unknownFormat == true`:

* Artifacts gate should be `WARN`, not `FAIL`
* Preflight should not block on WARN by default
* But it can say:

  * “Artifacts state unknown — recommended: wub index build”

This prevents first-time users from being stuck due to a refactor.

---

If you want the next continuation: I can show exactly how to integrate this into a full `StudioStateEvaluator` that returns gates + recommended action + paths, and how to produce the “STATION A▣ S▢ I▣ F×(3) R▢” line from the snapshot (including the `(stale)` detail rules).
Below is a concrete “full stack” integration: **StudioStateEvaluator → snapshot → bar render → Operator Shell header + SPACE behavior**, with the **exact `(stale)` and `(n)` rules**, plus a clean separation of files so this doesn’t rot.

I’ll keep it repo-realistic: small types, tolerant parsing, stable “next action” mapping.

---

## 1) File breakdown (recommended)

Create these files under:

`tools/automation/swift-cli/Sources/StudioCore/`

1. `StudioStateTypes.swift`
2. `RunLocator.swift`
3. `ReceiptSignal.swift`
4. `ArtifactIndexParser.swift`
5. `StudioStateEvaluator.swift`
6. `StudioStateRendering.swift` (bar + header text helpers)

Operator shell (`OperatorShellCommand.swift`) only consumes the evaluator + renderer.

---

## 2) `StudioStateEvaluator`: full snapshot with gates + recommended next

### 2.1 Types (StudioStateTypes.swift)

```swift
import Foundation

enum Gate: String, CaseIterable { case anchors = "A", sweep = "S", index = "I", artifacts = "F", ready = "R" }

enum GateStatus: Equatable {
  case pass
  case pending
  case warn(String)  // non-blocking
  case fail(String)  // blocking

  var isPass: Bool { if case .pass = self { return true } else { return false } }
  var isFail: Bool { if case .fail = self { return true } else { return false } }
  var isWarn: Bool { if case .warn = self { return true } else { return false } }
}

struct GateResult: Equatable {
  let gate: Gate
  let status: GateStatus
  let detailShort: String?  // "(3)" or "(stale)" or "(?)"
}

struct RecommendedNext: Equatable {
  let title: String          // for UI
  let command: [String]      // ["wub","assets","export-all",...]
  let danger: Bool
  let guided: Bool           // whether visible in GUIDED view
  let reason: String
}

struct StudioStateSnapshot: Equatable {
  let gates: [GateResult]          // always A,S,I,F,R in order
  let blockers: [String]
  let warnings: [String]
  let recommended: RecommendedNext?

  // Header / recovery affordances
  let anchorsPackName: String?
  let anchorsPackPath: String?
  let lastRunDir: String?
  let lastFailuresDir: String?
  let lastReceiptPath: String?
}
```

---

### 2.2 Evaluator (StudioStateEvaluator.swift)

```swift
import Foundation

struct StudioStateEvaluator {
  let repoRoot: URL
  let runsRoot: URL
  let now: () -> Date

  init(repoRoot: URL, runsRoot: URL = URL(fileURLWithPath: "runs"), now: @escaping () -> Date = Date.init) {
    self.repoRoot = repoRoot
    self.runsRoot = runsRoot
    self.now = now
  }

  func evaluate(
    anchorsPackPath: String?,
    lastRunDir: String?,
    lastFailuresDir: String?,
    lastReceiptPath: String?
  ) -> StudioStateSnapshot {

    // A) Anchors
    let (anchorsGate, anchorsName, anchorsPath) = evaluateAnchors(anchorsPackPath)

    // S) Sweep
    let sweepGate = evaluateSweep()

    // I + F) Index + Artifacts
    let (indexGate, artifactsGate) = evaluateIndexAndArtifacts()

    // R) Ready
    let readyGate = evaluateReady()

    let gates = [anchorsGate, sweepGate, indexGate, artifactsGate, readyGate]

    let blockers = gates.compactMap { gate -> String? in
      if case .fail(let msg) = gate.status { return "\(gate.gate.rawValue): \(msg)" }
      return nil
    }

    let warnings = gates.compactMap { gate -> String? in
      if case .warn(let msg) = gate.status { return "\(gate.gate.rawValue): \(msg)" }
      return nil
    }

    let recommended = recommendNext(gates: gates, anchorsPackPath: anchorsPath)

    return StudioStateSnapshot(
      gates: gates,
      blockers: blockers,
      warnings: warnings,
      recommended: recommended,
      anchorsPackName: anchorsName,
      anchorsPackPath: anchorsPath,
      lastRunDir: lastRunDir,
      lastFailuresDir: lastFailuresDir,
      lastReceiptPath: lastReceiptPath
    )
  }

  // MARK: - Gate evaluators

  private func evaluateAnchors(_ anchorsPackPath: String?) -> (GateResult, String?, String?) {
    guard let p = anchorsPackPath, !p.isEmpty else {
      return (GateResult(gate: .anchors, status: .fail("Anchors not set"), detailShort: nil), nil, nil)
    }

    let url = resolvePath(p)
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
      return (GateResult(gate: .anchors, status: .pass, detailShort: nil), url.lastPathComponent, url.path)
    }
    return (GateResult(gate: .anchors, status: .fail("Anchors path not found"), detailShort: nil), url.lastPathComponent, url.path)
  }

  private func evaluateIndexAndArtifacts() -> (GateResult, GateResult) {
    let indexURL = repoRoot.appendingPathComponent("checksums/index/artifact_index.v1.json")
    if !FileManager.default.fileExists(atPath: indexURL.path) {
      return (
        GateResult(gate: .index, status: .fail("Index missing"), detailShort: nil),
        GateResult(gate: .artifacts, status: .pending, detailShort: nil)
      )
    }

    let summary = loadArtifactIndexSummary(at: indexURL)

    // Index gate
    let indexGate: GateResult = summary.unknownFormat
      ? GateResult(gate: .index, status: .warn("Index format unknown"), detailShort: "(?)")
      : GateResult(gate: .index, status: .pass, detailShort: nil)

    // Artifacts gate
    if summary.unknownFormat {
      return (indexGate, GateResult(gate: .artifacts, status: .warn("Artifacts unknown"), detailShort: nil))
    }

    let bad = summary.missing + summary.placeholder
    if bad > 0 {
      return (indexGate, GateResult(gate: .artifacts, status: .fail("Missing/placeholder artifacts: \(bad)"), detailShort: "(\(bad))"))
    }
    return (indexGate, GateResult(gate: .artifacts, status: .pass, detailShort: nil))
  }

  private func evaluateSweep() -> GateResult {
    let locator = RunLocator(runsRoot: runsRoot)
    let url = locator.latestReceipt(matchingAny: ["sweep", "dubsweeper"])
    let obs = url.map(readReceiptSignal)

    let (status, detail) = gateStatusFromReceipt(
      obs,
      now: now(),
      staleAfterSeconds: 15 * 60,
      gateName: "Sweep"
    )
    return GateResult(gate: .sweep, status: status, detailShort: detail)
  }

  private func evaluateReady() -> GateResult {
    let locator = RunLocator(runsRoot: runsRoot)
    let url = locator.latestReceipt(matchingAny: ["ready", "verify"])
    let obs = url.map(readReceiptSignal)

    let (status, detail) = gateStatusFromReceipt(
      obs,
      now: now(),
      staleAfterSeconds: 60 * 60,
      gateName: "Ready"
    )
    return GateResult(gate: .ready, status: status, detailShort: detail)
  }

  // MARK: - Recommendation

  private func recommendNext(gates: [GateResult], anchorsPackPath: String?) -> RecommendedNext? {
    // Earliest FAIL wins, else earliest meaningful PENDING/WARN (stale)
    func firstFail() -> GateResult? { gates.first(where: { $0.status.isFail }) }
    if let g = firstFail() { return recommended(for: g, anchorsPackPath: anchorsPackPath) }

    // Treat Sweep warn(stale) as actionable
    if let sweep = gates.first(where: { $0.gate == .sweep }) {
      if case .warn(let msg) = sweep.status, msg.lowercased().contains("stale") {
        return RecommendedNext(
          title: "Sweep (modal guard)",
          command: ["wub", "sweep", "--modal-test", "detect", "--allow-ocr-fallback"],
          danger: false,
          guided: true,
          reason: "Sweep stale"
        )
      }
    }

    // Ready pending: recommend ready verify (optional)
    if let ready = gates.first(where: { $0.gate == .ready }),
       case .pending = ready.status {
      return RecommendedNext(
        title: "Ready: verify",
        command: ["wub", "ready", "verify"],
        danger: false,
        guided: true,
        reason: "Ready not verified"
      )
    }

    return nil
  }

  private func recommended(for gate: GateResult, anchorsPackPath: String?) -> RecommendedNext {
    switch gate.gate {
    case .anchors:
      return RecommendedNext(
        title: "Anchors: select",
        command: ["wub", "anchors", "select"],
        danger: false,
        guided: true,
        reason: "Anchors not configured"
      )

    case .sweep:
      return RecommendedNext(
        title: "Sweep (modal guard)",
        command: ["wub", "sweep", "--modal-test", "detect", "--allow-ocr-fallback"],
        danger: false,
        guided: true,
        reason: "Sweep not passing"
      )

    case .index:
      return RecommendedNext(
        title: "Index: build",
        command: ["wub", "index", "build"],
        danger: false,
        guided: true,
        reason: "Index missing"
      )

    case .artifacts:
      // If anchors missing, point back to anchors (but anchors fail should already have won)
      guard let ap = anchorsPackPath else {
        return RecommendedNext(
          title: "Anchors: select",
          command: ["wub", "anchors", "select"],
          danger: false,
          guided: true,
          reason: "Anchors required before exporting artifacts"
        )
      }
      return RecommendedNext(
        title: "Assets: export ALL",
        command: ["wub", "assets", "export-all", "--anchors-pack", ap, "--overwrite"],
        danger: true,
        guided: true, // show in GUIDED (but hide in SAFE)
        reason: "Missing/placeholder artifacts"
      )

    case .ready:
      return RecommendedNext(
        title: "Ready: verify",
        command: ["wub", "ready", "verify"],
        danger: false,
        guided: true,
        reason: "Ready verification failing"
      )
    }
  }

  // MARK: - Path resolution

  private func resolvePath(_ raw: String) -> URL {
    if raw.hasPrefix("~/") {
      let home = FileManager.default.homeDirectoryForCurrentUser
      return home.appendingPathComponent(String(raw.dropFirst(2)))
    }
    return URL(fileURLWithPath: raw)
  }
}
```

---

## 3) Receipt parsing + staleness mapping (ReceiptSignal.swift)

Use the parser we designed, but make it accept `now` and return `(GateStatus, detailShort)` deterministically.

```swift
import Foundation

enum ReceiptSignal: Equatable { case pass, fail(reason: String?), unknown(reason: String?) }

struct ReceiptObservation: Equatable {
  let url: URL
  let signal: ReceiptSignal
  let modifiedAt: Date?
}

func readReceiptSignal(from url: URL) -> ReceiptObservation {
  let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)

  guard
    let data = try? Data(contentsOf: url),
    let obj = try? JSONSerialization.jsonObject(with: data),
    let dict = obj as? [String: Any]
  else {
    return .init(url: url, signal: .unknown(reason: "unreadable"), modifiedAt: mtime)
  }

  func normalize(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

  func str(_ key: String) -> String? { dict[key] as? String }
  func bool(_ key: String) -> Bool? { dict[key] as? Bool }
  func int(_ key: String) -> Int? {
    if let n = dict[key] as? Int { return n }
    if let n = dict[key] as? Double { return Int(n) }
    if let s = dict[key] as? String, let n = Int(s) { return n }
    return nil
  }

  for k in ["status", "result", "outcome"] {
    if let v = str(k).map(normalize) {
      if ["pass","passed","ok","success"].contains(v) { return .init(url: url, signal: .pass, modifiedAt: mtime) }
      if ["fail","failed","error"].contains(v) { return .init(url: url, signal: .fail(reason: "\(k)=\(v)"), modifiedAt: mtime) }
    }
  }

  for k in ["ok","success","passed"] {
    if let v = bool(k) {
      return .init(url: url, signal: v ? .pass : .fail(reason: "\(k)=false"), modifiedAt: mtime)
    }
  }

  for k in ["exitCode","exit_code","terminationStatus"] {
    if let v = int(k) {
      return .init(url: url, signal: (v == 0 ? .pass : .fail(reason: "\(k)=\(v)")), modifiedAt: mtime)
    }
  }

  return .init(url: url, signal: .unknown(reason: "no recognized fields"), modifiedAt: mtime)
}

func gateStatusFromReceipt(
  _ obs: ReceiptObservation?,
  now: Date,
  staleAfterSeconds: TimeInterval,
  gateName: String
) -> (GateStatus, String?) {

  guard let obs else { return (.pending, nil) }

  let stale: Bool = {
    guard let m = obs.modifiedAt else { return false }
    return now.timeIntervalSince(m) > staleAfterSeconds
  }()

  switch obs.signal {
  case .pass:
    if stale { return (.warn("\(gateName) stale"), "(stale)") }
    return (.pass, nil)

  case .fail(let reason):
    return (.fail(reason ?? "\(gateName) failed"), nil)

  case .unknown(let reason):
    // unknown should not block first-run; make it WARN
    return (.warn(reason ?? "\(gateName) unknown"), nil)
  }
}
```

---

## 4) Artifact index tolerant parser (ArtifactIndexParser.swift)

Use the parser you asked for earlier (counts missing + placeholder) and return `unknownFormat` if no artifact-like objects found.

(Use the implementation I gave last turn; it plugs in directly.)

---

## 5) RunLocator (RunLocator.swift)

Use the implementation from earlier (latest run dirs, match patterns).

Key rule: scan only N recent runs.

---

## 6) Render the “STATION” bar line deterministically (StudioStateRendering.swift)

This is where `(stale)` and `(n)` join the token, and where spacing stays stable.

```swift
import Foundation

struct StationBarRender {
  static func symbol(for status: GateStatus) -> String {
    switch status {
    case .pass: return "▣"
    case .pending: return "▢"
    case .warn: return "!"
    case .fail: return "×"
    }
  }

  static func token(_ g: GateResult) -> String {
    // e.g. "A▣", "S!(stale)", "F×(3)"
    let base = "\(g.gate.rawValue)\(symbol(for: g.status))"
    if let d = g.detailShort { return base + d }
    return base
  }

  static func renderLine1(
    snapshot: StudioStateSnapshot,
    label: String = "STATION",
    width: Int,
    showSpaceHint: Bool = true
  ) -> String {
    // Fixed left block
    let gates = snapshot.gates
    let a = token(gates[0])
    let s = token(gates[1])
    let i = token(gates[2])
    let f = padRight(token(gates[3]), 6)   // reserve space for "(n)"
    let r = token(gates[4])

    let left = "\(padRight(label, 10))  \(a)  \(s)  \(i)  \(f)  \(r)"
    let suffix = showSpaceHint ? "   [SPACE]" : ""
    let nextText: String = {
      guard let rec = snapshot.recommended else { return "—   CLEARED" }
      return "\(rec.command.joined(separator: " "))"
    }()

    // Build "next:" area and truncate from middle
    let prefix = left + "    next: "
    var available = max(0, width - prefix.count - suffix.count)
    if available < 12 {
      // drop SPACE hint first
      return truncateTail(prefix + truncateMiddle(nextText, max(8, width - prefix.count)), width)
    }
    let nextTrunc = truncateMiddle(nextText, available)
    return prefix + nextTrunc + suffix
  }

  // Helpers (ASCII-safe length assumption)
  static func padRight(_ s: String, _ n: Int) -> String {
    if s.count >= n { return s }
    return s + String(repeating: " ", count: n - s.count)
  }

  static func truncateMiddle(_ s: String, _ maxLen: Int) -> String {
    if s.count <= maxLen { return s }
    if maxLen <= 1 { return "…" }
    let head = (maxLen - 1) / 2
    let tail = maxLen - 1 - head
    return String(s.prefix(head)) + "…" + String(s.suffix(tail))
  }

  static func truncateTail(_ s: String, _ maxLen: Int) -> String {
    if s.count <= maxLen { return s }
    if maxLen <= 1 { return "…" }
    return "…" + String(s.suffix(maxLen - 1))
  }
}
```

> You’ll use the path truncation routines we defined earlier for line 3; keep them separate from line 1.

---

## 7) Operator Shell: how to use snapshot + bar in the loop

Inside `OperatorShellCommand.run()`:

* Replace your existing “recommendedNextAction” computation with a cached evaluator snapshot.
* Re-evaluate every 0.5s idle / 1.0s running.
* After a run finishes, evaluate immediately and emit milestone toasts (gate transitions).

Pseudo integration:

```swift
let evaluator = StudioStateEvaluator(repoRoot: URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                                     runsRoot: URL(fileURLWithPath: "runs"))

var lastSnapshot: StudioStateSnapshot? = nil
var lastEvalAt = Date.distantPast

while true {
  toast.tick()

  let interval: TimeInterval = runnerIsRunning ? 1.0 : 0.5
  if Date().timeIntervalSince(lastEvalAt) >= interval || runnerJustFinished {
    let snap = evaluator.evaluate(
      anchorsPackPath: localConfig.anchorsPack, // already loaded in your shell
      lastRunDir: lastRunDir,
      lastFailuresDir: lastFailuresDir,
      lastReceiptPath: lastReceiptPath
    )

    if let prev = lastSnapshot {
      emitGateTransitionToasts(prev: prev, next: snap, toast: &toast)
    }
    lastSnapshot = snap
    lastEvalAt = Date()
  }

  // render header line 1 from lastSnapshot
  let header1 = StationBarRender.renderLine1(snapshot: lastSnapshot ?? fallbackSnap, label: "STATION", width: termWidth)

  // pass toast.currentText + header lines into printScreen(...)
  // ...
}
```

---

## 8) Gate transitions → milestone toasts (exact, deterministic)

```swift
func emitGateTransitionToasts(prev: StudioStateSnapshot, next: StudioStateSnapshot, toast: inout ToastManager) {
  let prevMap = Dictionary(uniqueKeysWithValues: prev.gates.map { ($0.gate, $0.status) })
  for g in next.gates {
    let old = prevMap[g.gate]
    let new = g.status

    // non-pass -> pass
    if (old == nil || !(old?.isPass ?? false)) && new.isPass {
      switch g.gate {
      case .anchors: toast.success("Anchors configured", key: "gate_pass_A")
      case .sweep:   toast.success("Sweep passed — no blocking modals detected", key: "gate_pass_S")
      case .index:   toast.success("Index built", key: "gate_pass_I")
      case .artifacts: toast.success("Artifacts complete", key: "gate_pass_F")
      case .ready:   toast.success("Studio ready", key: "gate_pass_R")
      }
    }

    // pass -> fail regression
    if (old?.isPass ?? false) && new.isFail {
      switch g.gate {
      case .anchors: toast.blocked("Anchors unavailable — check anchors pack path", key: "gate_regress_A")
      case .sweep:   toast.blocked("Sweep blocked — modal or permission", key: "gate_regress_S")
      case .index:   toast.blocked("Index missing — rebuild required", key: "gate_regress_I")
      case .artifacts: toast.blocked("Artifacts missing — export required", key: "gate_regress_F")
      case .ready:   toast.blocked("Studio not ready — verification failed", key: "gate_regress_R")
      }
    }
  }
}
```

---

## 9) The final “feel”: SPACE runs “next” consistently

In the Operator Shell:

* Use `snapshot.recommended` instead of ad-hoc logic.
* If `snapshot.recommended == nil`: toast “No pending actions — studio is ready”
* If `danger == true` and mode SAFE: toast “hidden — press s”
* If in GUIDED and recommended not guided: toast “press a”
* Else run it

This makes first-time use deterministic.

---

If you want the next step, I can draft the **exact updated `printScreen` header composition** (Line 1/2/3 + optional note line) using the width/truncation rules you approved, so the Operator Shell’s rendering is fully specified end-to-end.
