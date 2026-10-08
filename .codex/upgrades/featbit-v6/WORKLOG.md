# FeatBit v6.0.0 Upgrade Worklog

Append entries chronologically. [TODO.md](TODO.md) tracks progress; [CONTEXT.md](CONTEXT.md) holds scope and evidence. Use Asia/Shanghai dates and English only. Record files, commands, results, unverified items and the next step whenever work, scope or phase acceptance changes.

## 2026-10-08 · R001 · Diagnosis and scope confirmation

- Baseline: Chart 0.9.17 / App 5.4.10, repository commit `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b`.
- Compared the official v6 guide source, release notes, application configuration at tags 5.4.10/6.0.0 and the existing chart.
- Confirmed DAS retirement, removal of OLAP__ServiceHost, new Professional API ClickHouse parameters and missing initialization scripts.
- The user chose DA cleanup first and excluded SHOW_ENV_SECRETS_IN_HEADER, enabling Control Plane and historical experiment data conversion.
- No chart, application version or existing release skill changes; no database scripts or deployments executed.

### Offline diagnostic commands

```powershell
helm template v6diagnostic charts/featbit --set ui.image.tag=6.0.0 --set api.image.tag=6.0.0 --set els.image.tag=6.0.0 --set das.enabled=false

helm template v6diagnostic charts/featbit --set architecture.tier=professional --set kafka.enabled=true --set clickhouse.enabled=true --set ui.image.tag=6.0.0 --set api.image.tag=6.0.0 --set els.image.tag=6.0.0 --set das.enabled=false
```

Results: both commands exited 0. OLAP__ServiceHost was still rendered; Professional lacked OLAPProvider and ClickHouse__HttpEndpoint; v6 initialization scripts were absent. Helm emitted dependency merge warnings for redis/postgresql.architecture; these were not treated as new v6 issues.

These checks establish the original chart's rendering behavior only. Container startup, database migration, development deployment and end-to-end behavior were not verified.

Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R002 · Create persistent records and a resume skill

- Added `.codex/upgrades/featbit-v6/TODO.md`, `CONTEXT.md` and `WORKLOG.md`.
- Added the project skill `.agents/skills/featbit-v6-upgrade/SKILL.md`.
- Added a conditional upgrade entry point to AGENTS.md for restoring the plan, decisions and latest worklog. This change was reverted in R003.
- Verification: skill-creator's `quick_validate.py` passed; UTF-8 and 15 local references across five files passed; new document whitespace checks and `git diff --check` passed. Existing AGENTS.md Markdown line-break spaces were preserved.
- No changes to the chart, existing release skill or application versions; no deployment or database operations.
- Git state at this entry: AGENTS.md modified and four new untracked files; changes uncommitted.
- Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R003 · Revert task changes to the project rules file

- The user explicitly required AGENTS.md to remain unchanged because it belongs to the project rather than this task.
- Reverted only the upgrade entry point added in R002. Restored AGENTS.md to its saved original bytes; `git diff --exit-code -- AGENTS.md` passed.
- Updated TODO, CONTEXT and the dedicated skill with this constraint; removed project rule changes from V6-05.
- Kept R002 as history and marked its AGENTS.md change as reverted. Retained the persistent records and skill; new sessions can invoke `$featbit-v6-upgrade`.
- No chart upgrade phase implemented; no deployment or database operations. The four task files remained uncommitted.
- Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R004 · Create the v6 branch and adopt English

- The user requested English only and a `v6` branch for this upgrade.
- Ran `git switch -c v6` from `main` at `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b`; the branch was created and checked out, preserving the existing task files.
- Translated TODO, CONTEXT, WORKLOG and `.agents/skills/featbit-v6-upgrade/SKILL.md` into English, preserving phase status, decisions, evidence and historical entries.
- Saved the English-only preference and branch in the records and resume skill.
- Verification: `git branch --show-current` returned `v6`; skill-creator's `quick_validate.py` passed. English-only UTF-8 content, whitespace and 11 local links across the four task files passed validation. `git diff --check` passed, and AGENTS.md SHA256 remained `a7994f1ed795d3d9fd0522ecd4d11f91285d8f71244f0eb2c768a0937d09b6cf`.
- Chart implementation remains unstarted. The four task files are uncommitted; no deployment or database operations.
- Next step: V6-01, remove DA and its associated configuration.

## 2026-10-08 · R005 · Prepare publication and the V6-01 handoff

- The user authorized committing and pushing the upgrade setup on `v6`, then requested a prompt for implementing the first TODO phase in a new session.
- Updated the latest request in TODO; all implementation phases remain unstarted.
- Commit scope: `.codex/upgrades/featbit-v6/TODO.md`, `CONTEXT.md`, `WORKLOG.md` and `.agents/skills/featbit-v6-upgrade/SKILL.md`.
- Before publication, `git status` showed only those four untracked files; `git ls-remote --heads origin refs/heads/v6` found no remote branch. AGENTS.md matched its original SHA256 and had no Git diff.
- Publication commands: stage the four files, commit as `chore: persist FeatBit v6 upgrade plan`, then `git push --set-upstream origin v6`.
- At entry preparation the setup files are uncommitted. Use Git history and the remote branch to recover the resulting commit and publication status before resuming.
- Next session: invoke `$featbit-v6-upgrade`, implement V6-01 only, validate Standard / Professional / api-only rendering and update the saved records. Preserve the exclusions and leave AGENTS.md unchanged.

## 2026-10-08 · R006 · Separate private local settings from published history

- GitHub rejected the first push because ancestor commit `a36c72dfea52e00c235efa3eb6d7ef06fa6a475b` contained OAuth configuration in the local AKS values file. The four new upgrade records were not the source of the rejection.
- That ancestor contained two local AKS configuration files and changes disabling their ignore rules. Preserved the original `main` branch, backed up both private files and restored them locally with matching SHA256 hashes.
- Rebased the unpublished `v6` branch onto `f78ba88a96eefa485517c7fb54bd2bc8395ab907`, verified to be in published `origin/main` history. The upgrade setup commit became `3dfa859ac9f1d914ddce83dcd22d55a3a97df71a`.
- The upstream ignore rules are active on `v6`; both private files are ignored. Verified that the credential-containing ancestor is absent from `v6` and that the original `main` branch is unchanged.
- Updated TODO and CONTEXT with the published branch base and private-file handling. AGENTS.md still matches its original SHA256. Chart upgrade phases remain unstarted.
- Next operation: commit this checkpoint, retry `git push --set-upstream origin v6` and verify the remote tip. At entry preparation this checkpoint is uncommitted; recover final commit and publication status from Git.
- Next implementation step: V6-01 only.
