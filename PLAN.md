  # Creative OS Structural Split: Kernel / Operator / Shared Migration for a Polymath OS
  
  Migrate the repository to a kernel/ / operator/ / shared/ layout that enforces a domain‑agnostic execution kernel with
  multiple operator personas. This establishes Creative OS as a polymath operating system that can support music, video,
  photography, textiles, medical devices, spatial design, and future material domains without embedding domain semantics into
  the kernel. The migration is structural only: file moves, doc rehomes, path updates, checksum regeneration, and a minimal CI
  guard. No compatibility shims and no semantic changes to runtime behavior, schemas, or CLI flags.

  ———

  ## Invariants

  - The kernel never depends on operator paths or domain affordances.
  - Operator assets are never authoritative without kernel validation.
  - Shared contracts define truth across domains.

  ———

  ## Target Layout (Final)

  - kernel/
      - cli/
      - tools/
  - operator/
      - profiles/
      - packs/
      - notes/
  - shared/
      - specs/
      - specs/profiles/<profile>/
      - contracts/ (reserved, may be empty initially)
  - docs/
      - creative-os/
      - studio-operator/
      - shared/

  ———

  ## Scope

  In scope

  - Deterministic file moves and doc rehomes
  - Reference/path updates across code, configs, scripts, docs, CI
  - Checksum regeneration
  - Minimal CI guard enforcing kernel/operator boundary
  - Structural preparation for multi-domain (polymath) evolution

  Out of scope

  - CLI behavior changes
  - Schema content changes
  - Runtime logic changes
  - Compatibility shims or transitional aliases
  - Introduction of new domain runtimes or material logic

  ———

  ## Public Interfaces / Paths

  - CLI build/run path: kernel/cli
  - Operator assets: operator/profiles/, operator/packs/, operator/notes/
  - Shared contracts: shared/specs/, shared/specs/profiles/<profile>/, shared/contracts/
  - Schema $id values remain unchanged (creative-os.local)
  - No semantic changes to schemas or CLI flags

  ———

  ## Plan Steps (Implementation Sequence)

  1. Remove deprecated conceptual mapping
      - Delete docs/creative_os_mapping.md
      - No migration; structural separation replaces conceptual mapping
  2. Create new top-level structure
      - Create kernel/, operator/, shared/
      - Create docs/creative-os/, docs/studio-operator/, docs/shared/
      - Create shared/contracts/ (reserved, may be empty)
      - Add shared/contracts/README.md with a 1‑paragraph purpose statement
  3. Move kernel code and tooling
      - Move tools/automation/swift-cli → kernel/cli
      - Move entire tools/ tree → kernel/tools/
      - Includes schema_validate.py, checksum_generate.sh, governance/CI helper scripts
      - If kernel/tools/checksum_verify.sh exists, it moves to kernel/tools/checksum_verify.sh
      - No tooling remains at repo root
  4. Move operator assets
      - Move profiles/ → operator/profiles/
      - Move packs/ → operator/packs/
      - Move notes/ → operator/notes/
      - Operator assets are intent and affordance only, never authoritative
  5. Move and normalize shared specs
      - Move specs/ → shared/specs/
      - Move profiles/<profile>/specs/ → shared/specs/profiles/<profile>/
      - Deterministic merge rule: if a spec exists in both locations, shared/specs/ wins
      - Profile copy is deleted if identical or renamed if divergent
      - Renaming convention for divergent profile specs:
          - <spec-name>.profile-<profile>.<ext>
          - Example: device.schema.json → device.schema.profile-studio.json
      - Update all references to renamed profile specs
      - Reject duplicate $id values under shared/specs/**
  6. Re-home docs by authority and persona (explicit mapping + triage rule)
      - Shared docs → docs/shared/ (explicit list only):
          - docs/README.md
          - docs/overview/*.md
          - docs/release/**
      - Kernel docs → docs/creative-os/ (explicit list only):
          - docs/automation/**
          - docs/station/**
          - docs/agents_contract.md
          - Any remaining docs/** files that describe execution, safety, governance, determinism, or kernel architecture
      - Operator docs → docs/studio-operator/ (explicit list only):
          - docs/first_run.md
          - docs/modes.md
          - docs/capabilities.md
          - Any remaining docs/** files that describe operator workflows, personas, UI affordances, or creative practice
      - Decision rule for any doc not covered above:
          - If it is system‑wide orientation or release policy → docs/shared/
          - If it describes execution semantics or safety → docs/creative-os/
          - If it describes operator workflows or UX → docs/studio-operator/
      - Triage rule:
          - Any docs not explicitly listed must be triaged by filename in the PR as a table: old path → new path
      - Reserve docs/shared/compliance/ for evidence/audit posture (may be empty)
  7. Roadmap split
      - docs/creative-os/ROADMAP.md contains kernel milestones and cross‑cutting milestones with operator dependency
        annotations
      - docs/studio-operator/ROADMAP.md contains operator‑only milestones
      - No mixed‑scope roadmap documents remain
  8. Update all references and paths
      - Update paths in Makefile, .github/workflows/*.yml, local dev scripts, documentation examples, build/package configs,
        Swift hard‑coded paths, and any script referencing kernel/tools/
      - Canonical replacements:
          - tools/automation/swift-cli → kernel/cli
          - tools/ → kernel/tools/
          - profiles/ → operator/profiles/
          - packs/ → operator/packs/
          - notes/ → operator/notes/
          - specs/ → shared/specs/
          - profiles/<name>/specs/ → shared/specs/profiles/<name>/
          - tools/checksum_verify.sh → kernel/tools/checksum_verify.sh (if present)
  9. Documentation link rules (global)
      - All doc links are repo‑root‑relative across docs/**
      - No ../ links anywhere under docs/
      - Cross‑links use /docs/<section>/...
      - Verification: rg '\.\./' docs returns empty
  10. Checksums
      - Canonical script location: kernel/tools/checksum_generate.sh
      - All invocations updated to bash kernel/tools/checksum_generate.sh
      - If verification exists, use bash kernel/tools/checksum_verify.sh
      - No duplicate or wrapper scripts
      - Checksums include all new paths
  11. Kernel/operator boundary enforcement
      - Add lightweight CI or pre‑commit guard: rg 'operator/' kernel/ must return empty
      - Enforces Creative OS as a domain‑neutral kernel
  12. Repo metadata
      - Update root README to describe:
          - Creative OS as the kernel
          - Studio Operator as the first operator persona
          - Polymath trajectory across domains
      - Update contributing guidelines to reflect new structure and rules

  ———

  ## Testing & Verification

  - rg --files snapshot before/after to confirm all moves
  - rg sweep for old paths: profiles/, operator/packs/, operator/notes/, shared/specs/, kernel/tools/
  - Build check: kernel CLI builds from kernel/cli
  - Runtime smoke: run wub with updated paths if environment allows
  - Checksum verification:
      - bash kernel/tools/checksum_generate.sh
      - bash kernel/tools/checksum_verify.sh (if present)
  - Kernel/operator guard: rg 'operator/' kernel/ returns empty
  - Doc link guard: rg '\.\./' docs returns empty
  - Schema integrity: no duplicate $id under shared/specs/**

  ———

  ## Public API / Interface Changes

  - CLI location change: kernel/cli
  - Asset path changes: operator/profiles/, operator/packs/, operator/notes/
  - Contract path changes: shared/specs/, shared/specs/profiles/<profile>/, shared/contracts/
  - Schema $id values unchanged

  ———

  ## Assumptions & Defaults

  - Breaking path changes are acceptable
  - Kernel CLI remains wub; only location changes
  - Shared specs and contracts are authoritative
  - Operator assets are intent and workflow only
  - Studio Operator is the first persona, not the last
  - Creative OS is designed to scale across music, video, photography, textiles/fashion, medical devices, and spatial systems
