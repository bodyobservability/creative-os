# make ready

This patch adds/updates a `ready` target in your Makefile.

## What `make ready` does

It runs the **Ready verifier** (v1.7.14):

1) Ensures the CLI is built (`make build` dependency)
2) Runs:
   - `wub ready --anchors-pack-hint <ANCHORS>`

The verifier checks (best-effort):
- artifact index exists + missing/placeholder counts
- anchors pack path exists (warn if missing)
- latest drift status (if a drift report exists)

It prints:
- `READY | WARN | NOT_READY`
- recommended next commands

## Usage

```bash
make ready
```

Override anchors pack if needed:

```bash
make ready ANCHORS=specs/automation/anchors/<your_pack_dir>
```
