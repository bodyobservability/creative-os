# Verify: creative-os bundle support (Ship Bundle 0)

This bundle adds `cos bundle` support to Creative-OS.

## Apply

From the bundle directory:

```bash
bash apply.sh --target /path/to/creative-os --force
```

## Verify

From the target repo root:

```bash
bash verify.sh
```

Success criteria:
- Prints: `OK: creative-os bundle CLI available`

## Notes
- This is a local-only feature. It enables: import → plan → apply of bundle zips containing `bundle_manifest.v1.json` at root.
