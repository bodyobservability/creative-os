# First Run

## One Command

Run:

```bash
make onboard
```

Outcome is always one of:

- CLEARED: Studio is ready. Voice + automation are safe to use.
- BLOCKED: Blockers, next commands, and where to look in `runs/<id>/...`.

`wub check` is the meter (read-only truth). `wub preflight` is the gate (enforces readiness).

## Readiness Pipeline (Definition of Done)

1. Anchors pack configured
2. Sweep passes (modal/perception sanity)
3. Index exists
4. Artifacts complete (no missing or placeholder)
5. Ready verify passes

## Anchors Pack (What and Why)

Anchors define UI regions and coordinates for automation. Without a valid anchors pack, UI automation is unreliable and preflight will block.

## Where Receipts and Logs Live

Every action writes receipts and logs under:

- `runs/<id>/...`

## Recovery by Symptom

### No anchors pack configured

Run:

```bash
wub anchors select
```

Or:

```bash
wub ui --anchors-pack <path>
```

### Sweep failed due to modals or permissions

Run:

```bash
wub sweep --modal-test detect --allow-ocr-fallback
```

Then re-run:

```bash
wub preflight
```

### Artifacts missing or placeholders detected

Run:

```bash
wub assets export-all --anchors-pack <path> --overwrite
```

Then rebuild:

```bash
wub index build
```

### Drift detected

Run:

```bash
wub drift plan --anchors-pack-hint <path>
```

Then:

```bash
wub drift fix --anchors-pack-hint <path>
```

### Ready verify fails

Run:

```bash
wub ready --anchors-pack-hint <path>
```

If still failing:

```bash
wub repair --anchors-pack-hint <path>
```

## How to Read the STATION Bar

The Operator Shell and `wub check` show:

```
STATION  A  S  I  F  R
```

Meanings:

- A = Anchors configured
- S = Sweep passes
- I = Index built
- F = Files/Artifacts complete
- R = Ready verify

Symbols:

- ▣ pass
- ▢ pending
- ! warn
- × fail


## Help Overlay

Press `?` in the Operator Shell to see the bar legend, mode meanings, and key bindings.
