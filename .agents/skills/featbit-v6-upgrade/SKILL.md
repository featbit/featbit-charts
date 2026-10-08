---
name: featbit-v6-upgrade
description: Continue this repository's FeatBit 5.4.10 to 6.0.0 Helm chart upgrade across sessions using the saved TODO, decisions, evidence and worklog. Use for resuming this upgrade, implementing an upgrade phase, or recording its progress; not for unrelated FeatBit releases.
---

# Resume the FeatBit v6 Upgrade

This skill is specific to the featbit-charts upgrade to v6.0.0. User-confirmed records define the sequence and scope without depending on the previous session's chat memory. A new session can explicitly invoke `$featbit-v6-upgrade`. Use English only in communication, task records and skill instructions.

## Restore the checkpoint

When starting work on this upgrade:

1. Read [TODO.md](../../../.codex/upgrades/featbit-v6/TODO.md) for the checkpoint, phase status and acceptance criteria.
2. Read [CONTEXT.md](../../../.codex/upgrades/featbit-v6/CONTEXT.md) for user decisions and evidence relevant to the current phase, and the latest entries in [WORKLOG.md](../../../.codex/upgrades/featbit-v6/WORKLOG.md).
3. Read AGENTS.md for project rules, then check the actual branch, Git status and relevant files. The upgrade branch is `v6`. The saved baseline does not replace the current working tree; preserve existing uncommitted changes.
4. Determine the scope from the user's current request and resume the appropriate unfinished phase. Briefly state the restored phase and next action.

Links are relative to this skill directory. From the repository root, read `.codex/upgrades/featbit-v6/` directly. If records are missing, recover facts from code and user context, mark unknowns and do not invent completion status.

## Decisions for this upgrade

- Proceed in phases: complete DA cleanup first and validate before moving on.
- Do not modify AGENTS.md. It contains project rules; this upgrade's entry points, state and context belong in .codex and the dedicated skill.
- Use English only.
- Do not handle `SHOW_ENV_SECRETS_IN_HEADER`.
- Do not enable Control Plane or add its optional services and configuration.
- Do not implement historical experiment data conversion or historical report recovery; separate scripts/programs handle those.
- Keep required v6 schema and new installation initialization integration in scope. Existing database migrations remain manual.
- When the user requests only planning, record maintenance or one phase, complete that scope. When authorized to continue the entire upgrade, proceed sequentially without asking again for existing authorization. Records and TODOs do not authorize publishing, production deployment or external database operations.

Follow subsequent user changes and update the records accordingly.

## Implementation details to preserve

- v6 has three core application images: UI/API/ELS. The [general release skill](../upgrade-featbit-chart/SKILL.md) still describes four images; use its applicable release guidance, but do not upgrade or retain the DAS image for this release.
- When removing `das-pro-env`, retain Kafka helpers and ClickHouse wait credentials that still have callers. Do not delete the entire `_pro-env.tpl`.
- Remove `OLAP__ServiceHost`. Put Professional's new `OLAPProvider` / `ClickHouse__*` configuration in the API. The business `DbProvider` remains PostgreSQL/MongoDB.
- API environment variables do not change the database, Kafka or topology settings in ClickHouse SQL. Adapt SQL to the actual environment using the evidence in CONTEXT.
- Historical release/migration documents and DAS references in these records may remain. Residual checks should focus on current deployment logic.
- Intermediate rendering success does not replace complete schema, runtime and end-to-end verification.

## Maintain the records

After a phase, a material decision, or before ending the requested work:

- Update genuinely completed TODO items, phase status, the checkpoint and next step. Mark a phase complete only after its acceptance criteria pass.
- Append the date, phase ID, changed files, verification commands/results, unverified items or blockers and next step to WORKLOG. Record a commit SHA when available; otherwise state that changes are uncommitted.
- Update CONTEXT when scope or verified facts change, retaining the reason and evidence links.
- Correct discrepancies between recorded status and actual files with an explanation. Do not repeat verification that remains valid and unchanged.
- Keep all new entries in English.
- Do not copy real credentials, connection details or complete output containing passwords from local values.

Before handoff, confirm the three records agree. A later session should be able to recover what changed, why it changed, what was verified and the next task from these files.
