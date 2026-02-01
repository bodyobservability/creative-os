# Fresh Machine Smoke Checklist (Per Release)

Goal: verify a clean machine can run the Creative OS workflows end-to-end.

Prereqs:
- macOS 13+ with required audio tools installed
- repo cloned with git submodules (if any)
- Ableton installed and licensed
- any required controllers connected

Checklist:
- [ ] `cd tools/automation/swift-cli && swift build -c release`
- [ ] `tools/automation/swift-cli/.build/release/wub sweep --json` (confirm JSON output)
- [ ] `tools/automation/swift-cli/.build/release/wub plan --json` (confirm JSON output)
- [ ] `tools/automation/swift-cli/.build/release/wub setup --show-manual` (confirm no automated steps fail)
- [ ] `tools/automation/swift-cli/.build/release/wub profile use wub` (confirm notes/WUB_CONFIG.json written)
- [ ] Station gating check: `tools/automation/swift-cli/.build/release/wub station status --format json --no-write-report`
- [ ] If assets are expected, run the appropriate export flow and verify outputs exist

Notes:
- Record the run id and any failures in release notes.
- If any step requires manual intervention, document the exact instructions.
