# Studio Guide

This guide is for day-to-day operation using `wub`.

## Build and run

```bash
cd tools/automation/swift-cli
swift build -c release
```

```bash
tools/automation/swift-cli/.build/release/wub sweep
tools/automation/swift-cli/.build/release/wub plan
tools/automation/swift-cli/.build/release/wub setup --show-manual
```

Legacy automation commands:
```bash
tools/automation/swift-cli/.build/release/wub sweep
```

## Profiles

```bash
tools/automation/swift-cli/.build/release/wub profile use hvlien
```

## Station status

```bash
tools/automation/swift-cli/.build/release/wub station status --format human
```
