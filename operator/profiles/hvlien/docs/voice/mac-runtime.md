# Mac Runtime Bridge (Voice → MIDI)

## Version
Version: current

## History
- (none)


**Goal:** Spoken phrase → exactly one MIDI event on the dedicated bus `WUB_VOICE` (IAC).  
**Non-goal:** Any Ableton assets, macro mappings, rack design, or sound semantics (that is v9.3).

This bridge is intentionally thin and debug-friendly.

---

## Recommended implementation (v9.2.0)

**Blessed path:**

1) macOS **Voice Control** custom command  
→ 2) **Keyboard Maestro** macro  
→ 3) `sendmidi` CLI  
→ 4) **IAC Driver** port `WUB_VOICE`

This yields deterministic, low-friction runtime triggers.

---

## 0) Preconditions

- Ableton Live 12.3 on macOS (can be closed during early testing)
- Voice Control enabled (System Settings → Accessibility → Voice Control)
- Audio MIDI Setup available (built-in)
- Optional: MIDI Monitor app (for debugging)

---

## 1) Enable Virtual MIDI Bus (IAC Driver)

1. Open **Audio MIDI Setup**
2. Press **⌘2** to open **MIDI Studio**
3. Double-click **IAC Driver**
4. Check: **Device is online**
5. Add a port named: **WUB_VOICE**

### Acceptance
- A port named `WUB_VOICE` exists and is online.

---

## 2) Install a MIDI sender CLI (sendmidi)

Install (example): Homebrew `sendmidi`.

Your MIDI sender must be able to:
- send CC
- send Note On
- address an output port by name

### Acceptance test (Terminal)
Send a CC and a Note to `WUB_VOICE` and confirm the port receives it (via MIDI Monitor or Ableton MIDI indicator).

---

## 3) Create Keyboard Maestro Macros (1 macro per trigger)

Naming convention:
- `VRL::wub_up`
- `VRL::sidechain_on`
- `VRL::arm_bass`
etc.

Each macro should do **exactly one** thing:
- Execute a shell command that sends the MIDI event to `WUB_VOICE`

Example structure:
- **Execute Shell Script**:
  - `sendmidi dev "WUB_VOICE" ch 1 cc 14 96`
  - or `sendmidi dev "WUB_VOICE" ch 1 on 60 127`

### Acceptance
- Running the KM macro emits one correct MIDI event every time.

---

## 4) Map Voice Control phrases → KM macros

In Voice Control:
- Commands… → “+”
- **When I say:** `wub up`
- **Perform:** Run Keyboard Maestro macro → `VRL::wub_up`

Repeat for the v9.1 starter trigger set.

### Phrase hygiene
- Keep phrases short and distinct
- Avoid homophones
- If misfires occur, prefix phrases with `hv` (e.g. “hv wub up”)

### Acceptance
- Speaking the phrase triggers the matching KM macro and sends the MIDI event.

---

## 5) Debug ladder (must always work)

Test in this order:

1) **Terminal** → sendmidi → IAC (`WUB_VOICE`)  
2) **Keyboard Maestro** → macro → IAC  
3) **Voice Control** → KM macro → IAC  
4) Ableton MIDI Map (v9.3; separate)

If a higher rung fails, drop down one rung and isolate.

---

## 6) Runtime safety rules

- Use explicit ON/OFF notes for toggles whenever possible:
  - `sidechain_on` note 60
  - `sidechain_off` note 61
- Do not encode multi-action phrases (no sequences) in v9.
- Keep all runtime output on `WUB_VOICE` only.

---

## 7) Files & Specs

The v9.1 trigger spec is the source of truth:

- `shared/specs/profiles/hvlien/voice/runtime/vrl_triggers.v1.yaml`
- `shared/specs/profiles/hvlien/voice/runtime/vrl_triggers.schema.v1.json`

v9.2.0 does not generate macros automatically — it documents the bridge.
(v9.2.1 may add an optional generator later.)

---

## Definition of done (v9.2)

- At least 3 phrases work reliably (10/10 activations each):
  - one CC trigger
  - one Note trigger
  - one Track/Scene trigger
- All events arrive on `WUB_VOICE` consistently.
- Terminal → KM → Voice debug ladder works end-to-end.
