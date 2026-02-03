# Operator Shell (Full Bundle)

Version: v1.7.4


This bundle is the **complete** Operator Shell package combining v1.7.2 + v1.7.3 + v1.7.4 features.

## Command
- `wub ui`

## Features
- Numbered menu with safe confirmations for “clicky/overwrite” actions
- Arrow-key navigation (↑/↓) + vim keys (j/k)
- Recommended next action hint
- Shortcuts:
  - `r` open last receipt
  - `o` open last report
  - `f` open last run folder
  - `x` open last failures folder
  - `q` quit
- Local config stored in `notes/LOCAL_CONFIG.json`

## Files
- tools/automation/swift-cli/Sources/StudioCore/OperatorShellCommand.swift
- tools/automation/swift-cli/Sources/StudioCore/LocalConfig.swift
- profiles/hvlien/docs/voice/operator-shell.md

## Wiring
Add `UI.self` to your CLI entrypoint (`CliMain.swift` or `main.swift`).

## Git hygiene
Add to `.gitignore`:
- `notes/LOCAL_CONFIG.json`
