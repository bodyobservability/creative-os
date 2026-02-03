# Contributing

Thanks for helping keep the Studio Operator (Creative OS profile) consistent and versioned.

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

Follow the rules in `profiles/hvlien/notes/versioning-rules.md` and update specs in `profiles/hvlien/specs/` when making structural changes.

Creative OS naming conventions:
- Prefer deversioned filenames for docs/specs; keep versions inside the document body or metadata.
- When a spec or doc is superseded, replace or move it into an explicit `history/` folder rather than keeping versioned filenames.


## Checksum discipline

This repo uses checksum manifests under `checksums/`. If you change any files under `specs/`, `docs/`, `profiles/*/specs`, `profiles/*/docs`, `notes` (excluding local-only configs), `controllers/`, or `ai/`, you must regenerate checksums before committing:

```bash
bash tools/checksum_generate.sh
```

To avoid missing this step, install the pre-commit hook:

```bash
bash tools/git-hooks/install.sh
```

This also installs a pre-push hook that verifies checksums before push.

CI enforces checksum freshness and will fail if checksums are out of date.

## Legacy files

We do not keep legacy bundles or historical status docs solely for audit trails. If a file is superseded, remove it rather than archiving.
