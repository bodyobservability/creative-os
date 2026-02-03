# HVLIEN v1.7.5 — Operator Shell Anchor Auto-Detect

This bundle updates the operator shell to auto-detect the newest anchor pack folder in the repo,
and persist it to `notes/LOCAL_CONFIG.json`.

Files:
- OperatorShellCommand.swift
- LocalConfig.swift
- profiles/hvlien/docs/voice/operator-shell.md

Wiring:
- Ensure `UI.self` is wired in your CLI entrypoint.
