# Contributing

Thanks for helping keep the Studio Operator (HVLIEN profile) consistent and versioned.

## Commit message standard

Use Conventional Commit-style prefixes so history stays readable and tooling-ready.

Format:

```
<type>(optional-scope): <short summary>
```

Rules:
- Use lowercase `type`.
- Keep the summary in imperative mood ("add", "fix", "document").
- Keep it short; no trailing period.
- One change set per commit when possible.

Allowed types:
- `feat`: new capability, spec, or artifact
- `fix`: bug or correction
- `docs`: documentation-only change
- `refactor`: internal change without behavior change
- `perf`: performance improvement
- `test`: add or update tests
- `chore`: tooling, cleanup, or maintenance
- `build`: build system or dependencies
- `ci`: CI configuration
- `revert`: revert a prior commit

Examples:
- `feat: add v1.4 specs and artifacts`
- `docs: clarify checksum regeneration step`
- `fix(ai): correct controller mapping range`

## Versioning and artifacts

Follow the rules in `profiles/hvlien/notes/VERSIONING_RULES.md` and update specs in `profiles/hvlien/specs/` when making structural changes.

## Legacy files

We do not keep legacy bundles or historical status docs solely for audit trails. If a file is superseded, remove it rather than archiving.
