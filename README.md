# Eclipse Agent Studio CLI

A fast, minimal-dependency CLI for managing services, workspaces, volumes, and more on the Eclipse Agent Studio platform.

[Claude Code](#claude-code) | [Gemini CLI](#google-gemini-cli) | [Codex](#openai-codex) | [CLI Only](#cli-only-linuxmacos) | [CLI Usage](#quick-start)

## AI Agent Integration

The `ast` skill uses the [Agent Skills open standard](https://agentskills.io/specification)
and works across Claude Code, Google Gemini CLI, and OpenAI Codex.

### Claude Code

**Plugin** (recommended — auto-installs binary + skill):

```bash
# 1. Add the marketplace (one time)
/plugin marketplace add https://github.com/Eclipse-Space/ast-cli

# 2. Install the plugin
/plugin install ast
```

Or use `/plugin` and follow the interactive menu.

This installs the `ast` plugin, which:
- Adds the `/ast:ast` skill to Claude Code
- Adds the `/ast:setup` command for guided onboarding

After installing, reload plugins to activate the new commands (no restart needed):

```
/reload-plugins
```

Then run `/setup` to get started:

```
/ast:setup
```

This will check if you're logged in, walk you through authentication (or registration), and help you create your first workspace and server.

**Standalone skill** (skill only):

```bash
curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install-claude-skill.sh | bash
```

Installs the binary and skill to `~/.claude/skills/ast/`.
Run `/reload-plugins` to activate `/ast` without restarting.

---

### Google Gemini CLI

**Extension** (recommended — includes context file + skill):

```bash
gemini extensions install https://github.com/Eclipse-Space/ast-cli
```

**Standalone skill** (skill only):

```bash
curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install-gemini-skill.sh | bash
```

Installs the binary and skill to `~/.gemini/skills/ast/`.
Restart Gemini CLI to activate.

---

### OpenAI Codex

```bash
curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install-codex-skill.sh | bash
```

Installs the binary and skill to `~/.codex/skills/ast/`.
Restart Codex to activate.

---

## CLI Only (Linux/macOS)

For terminal users who want the `ast` binary without AI agent integration.

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install.sh | bash
```

This downloads the pre-built binary for your platform, verifies its checksum, and installs it to `~/.local/bin/ast`.

To install to a custom location:

```bash
AST_INSTALL_DIR=/usr/local/bin curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install.sh | bash
```

### Build from source

If the one-liner doesn't work (e.g., restricted network, unsupported platform), you can build from source.

**Dependencies:**
- [git](https://git-scm.com/downloads)
- [Rust/cargo](https://rustup.rs) — install with: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`

```bash
git clone https://github.com/Eclipse-Space/ast-cli.git
cd ast-cli
cargo build --release
cp target/release/ast ~/.local/bin/
```

## Quick Start

### 1. Authenticate

Log in via browser (OAuth2 PKCE flow):

```bash
ast auth login
```

This opens your browser to the Keycloak login page, captures the auth token, and stores it securely in your OS keychain.

To target a specific environment:

```bash
ast auth login --env dev
ast auth login --env test
```

### 2. Verify Your Identity

```bash
ast auth whoami
```

### 3. List Workspaces

```bash
# JSON output (default)
ast workspaces get

# Table output
ast workspaces get --format table

# Filter by organization
ast workspaces get --organization-id <ORG_ID>
```

### 4. Log Out

```bash
ast auth logout
```

## Authentication Methods

The CLI supports multiple auth methods, resolved in this priority order:

| Priority | Method | Usage |
|----------|--------|-------|
| 1 | Bearer token | `--bearer-token <TOKEN>` or `AST_BEARER_TOKEN` env var |
| 2 | API key (CLI) | `--api-key <KEY>` or `AST_API_KEY` env var |
| 3 | API key (config) | Stored in `~/.ast/config.yaml` |
| 4 | Keychain token | Stored automatically after `auth login` |

Config, tokens, and upload checkpoints live under `~/.ast/` by default; set
`AST_CONFIG_DIR` to relocate all of them (see server mode below).

### Using an API Key

```bash
# Via flag
ast workspaces get --api-key <YOUR_KEY>

# Via environment variable
export AST_API_KEY=<YOUR_KEY>
ast workspaces get
```

### Server mode — running `ast` inside a service

Long-running services (the MCP gateway, the SimRunner server) subprocess `ast`
with injected credentials. Set this environment for every invocation so the
CLI touches nothing outside the service's own scratch space:

```bash
AST_BEARER_TOKEN=<token>      # or AST_API_KEY — the injected credential
AST_NO_DOTENV=1               # ignore any .env in/above the working directory
AST_CONFIG_DIR=/scratch/ast   # config, token, and upload checkpoints go here, not $HOME
AST_TELEMETRY_DISABLED=1      # no PostHog events, no ~2 s flush per invocation
AST_ORGANIZATION_ID=<org>     # pin context explicitly
AST_WORKSPACE_ID=<ws>         # pin context explicitly
```

With this contract in place:

- A stray `.env` in the service working tree cannot override the injected
  credential (without `AST_NO_DOTENV`, `.env` values take precedence over
  inherited environment variables by design).
- No `~/.ast` is created or read — all state follows `AST_CONFIG_DIR`.
- An explicit `AST_BEARER_TOKEN`/`--bearer-token` or API key never triggers
  the OAuth refresh path, so an auth failure surfaces immediately instead of
  reading and rewriting the stored token file. Refresh still works for
  interactive `auth login` sessions.

These behaviors are pinned by the `tests/server_mode.rs` integration tests.

## Environments

| Name | Flag | API |
|------|------|-----|
| Production (default) | `--env prod` | `api.studio.eclipse.space` |
| Staging | `--env staging` | `api.studio.staging.eclipse.space` |
| Dev | `--env dev` | `api.studio.dev.eclipse.space` |

## Commands

```
ast auth login       Log in via browser (OAuth2 PKCE)
ast auth logout      Clear stored credentials
ast auth whoami      Show current user info
ast workspaces get   List workspaces
ast secrets get      List secrets (metadata only)
ast secrets create   Create a secret
ast secrets edit     Change a secret's value or workspace exposure
ast secrets delete   Delete a secret
ast rules get-*      Show platform/organization/workspace/service/user rules
ast rules edit-*     Replace organization/workspace/service/user rules
ast processes get    Process discovery index (which service, volume and workspace run each process)
ast preauth status   Show per-name pre-auth enrollment status (on a server)
ast preauth seed     Store this server's gh + Claude logins on the platform
ast refresh          Re-sync skills, rules, MCP config and secrets (on a server)
ast refresh --check  Report drift without writing (exit 3 when drift is found)
```

Further command groups: `organizations`, `members`, `volumes`, `volume-data`,
`services`, `service-jobs`, `persistent-services`, `processes`, `skills`,
`servers`, `mcp-servers`, `api-keys`, `preauth`, `refresh`, `rules`, `schema`.
Run `ast <group> --help` for details.

## Volume Data

```bash
# Upload a file (multipart + resumable above 50 MiB; re-run after an
# interruption to resume from the last completed part)
ast volume-data upload --volume-id <VOL_ID> --file ./results.zip --key results/results.zip

# Download files — nested keys work, content is streamed to disk. Since
# 0.1.4 the key's directory structure is preserved under --output-dir
# (this example writes ./results/sim-runner/jobs/<SIM_ID>/results/out.bin);
# pass --flat for the pre-0.1.4 layout (./results/out.bin)
ast volume-data download --volume-id <VOL_ID> \
  --keys sim-runner/jobs/<SIM_ID>/results/out.bin --output-dir ./results

# Presign for external tools — bare URL(s) on stdout with --format table
# (URLs expire after 24 h; for multipart sizes the part URLs print one per
# line with uploadId/partSize on stderr); --format json returns the full
# contract, including multipart part URLs + uploadId for large presigned
# uploads
aria2c -x16 "$(ast volume-data presign --volume-id <VOL_ID> --key results/out.bin --format table)"

# Register an object uploaded via presigned PUT (uploads via
# `ast volume-data upload` finalize automatically)
ast volume-data finalize --key results/out.bin
```

## Skills

```bash
# Download a skill's package archive
ast skills download --skill-id <SKILL_ID>                    # → ./<name>.zip
ast skills download --skill-id <SKILL_ID> --output pkgs/     # → pkgs/<name>.zip
ast skills download --skill-id <SKILL_ID> --output my.zip    # exact path
```

**Package-fetch contract** (for consumers mirroring this operation, e.g. the
MCP gateway's `load_skill`):

- The operation is the `getSkillDownload(skillId)` GraphQL query, returning
  `{ skillId, name, url }`. The `url` is a presigned HTTPS GET valid for
  **24 hours** (`X-Amz-Expires=86400`), same TTL as volume-data presigns.
- The `s3Url` field on `getSkills` is an `s3://` storage locator and **cannot
  be fetched directly** — always go through `getSkillDownload`.
- The archive is a **zip** with `SKILL.md` at the root (the Agent Skills
  package layout used by `skills create`/`replace-package`).

## Persistent Services

Persistent services are long-running solver/tool instances that cache state
between jobs. Jobs queue even when the service is stopped — the platform
auto-starts a stopped service that has queued jobs.

```bash
# List services / inspect one (detail shows the tools it exposes)
ast persistent-services get --workspace-id <WS_ID> --format table
# narrow the selection — the full record carries serviceSchema + serviceRules (tens of KB each)
ast persistent-services get --organization-id <ORG_ID> --fields name,persistentServiceId,status

# Submit a job — the payload is {"tool": ..., "inputs": {...}}; volume paths
# use the volume UUID and each volume is declared with --volumes
ast persistent-services jobs create \
  --persistent-service-id <PS_ID> \
  --volumes <VOLUME_UUID> \
  --payload '{"tool": "no_solve", "inputs": {"project_file": "/workspace/volumes/<VOLUME_UUID>/in.aedt"}}'

# Poll status (single-shot; JSON output is the job object — check .completedAt;
# terminal jobs carry presigned log/result URLs, ~24 h expiry — re-run for
# fresh links)
ast persistent-services jobs status --ps-job-id <PS_JOB_ID>

# Lifecycle + queue management
ast persistent-services start|stop|restart --persistent-service-id <PS_ID>
ast persistent-services jobs cancel --ps-job-id <PS_JOB_ID>
```

## Processes

`ast processes get` builds the **process discovery index**: for every
persistent service in the organization, which process it runs, on which store
volume and jobs workspace, with which tools. It is what the job-runner skill
reads on editors and in Claude Code, and what the gateway serves Claude
Desktop through `run_ast(["processes", "get", "--organization-id", …])` — so
environment-specific ids are never stored in a skill package or a gateway
table; every surface reads the current environment's ids at run time.

```bash
# The index. Organization-scoped: --organization-id, else AST_ORGANIZATION_ID,
# else the configured organization (`ast orgs use`). --workspace-id only
# narrows — it is deliberately not read from AST_WORKSPACE_ID.
ast processes get --organization-id <ORG_ID>

# Filters (exact; --extension is case-insensitive, leading dot optional)
ast processes get --extension .aedt
ast processes get --domain fab --process fab-package
ast processes get --name fab-package-automation --format table
```

The bindings are authored in a `process.yaml` next to `service.yaml`, pointed
at by a top-level `process:` key — the sibling of `rules:`:

```yaml
# service.yaml
rules: README.md        # the agent-facing process document
process: process.yaml   # the discovery block this verb reads
```

```yaml
# process.yaml
eclipse_process: 1                 # convention version (required, must be 1)
process: fab-package               # process family (required)
domain: fab                        # eclipse.job/1 descriptor the job rides (required)
label: PCB fab package (validate a _FAB.zip / assemble from parts)
volume_name: PCB/PCBA Automation Workspace Volume   # store volume, exact name (required)
workspace_name: PCB/PCBA Automation                 # jobs workspace, exact name (required)
runtime_class: minutes             # seconds | minutes | hours — for every tool, or a per-tool map
preflight: self_validating         # dry_run | self_validating | none — likewise (`no_solve` = dry_run)
extension_hints:                   # input extension -> tools on THIS service
  .zip: [validate]
  .xlsx: [assemble]
  .tgz: [assemble]
results:                           # for every tool, or a per-tool map of these keys
  report_glob: "results/*_report.json"
default_inputs:                    # keyed by tool, never flat
  validate: {formats: "md,json"}
```

The full field reference is [`docs/process-yaml.md`](docs/process-yaml.md); the
machine-readable copy is [`schemas/process.schema.json`](schemas/process.schema.json)
(kept in step with the parser by a unit test).

`ast services deploy` validates the file before any network or Docker work —
it must be a well-formed document, and every tool it names (in
`extension_hints`, the per-tool maps, `results`, and `default_inputs`) must exist under
`service.tools`, with every default naming a declared input — and then folds
it into the service schema as its `process` key. The platform snapshots that
schema onto the persistent-service record as `serviceSchema`, next to the
`rules:` document, and a persistent-service update (`upgradeToLatestVersion`)
refreshes both. The file carries no ids: the persistent-service and service
ids come from the record, and the names resolve in whichever environment reads
them. Per record:

- `workspace_name` resolves to `workspace_id` by **exact** name within the
  organization. `volume_name` resolves against the organization's volumes
  **plus the volumes attached to that workspace** — a workspace's own volume
  (`<workspace> Workspace Volume`) is not in the organization-scoped listing.
  A name neither has is looked up once more among every volume the caller can
  list in the organization (the `ast volumes get` listing, which keeps
  workspace volumes — including one whose workspace was deleted).
  Zero or several matches emit `volume_resolution` / `workspace_resolution`
  (`not_found` | `ambiguous`, with the candidates) and a `null` id — the verb
  never guesses.
- `runtime_class` and `preflight` are always emitted as **per-tool maps**. A
  scalar in the file applies to every tool and is expanded over the schema's
  tools; a map names tools explicitly (a multi-stage service: prep in
  minutes, the solve in hours). `default_inputs` is keyed by tool
  (`{validate: {formats: "md,json"}}`); a flat mapping is rejected.
- `results` normalizes the same way: a flat block of result keys (`glob`,
  `log_glob`, `report_glob`, `manifest`, `log_family`) applies to every tool,
  a per-tool map names tools, and the output is always tool -> keys. A block
  that mixes result keys with tool names is refused. `preflight` values are
  `dry_run` (a separate cheap check exists), `self_validating` (the run fails
  fast on bad inputs), `none`; `no_solve`, the Ansys flag name the first
  drafts used, is read as `dry_run`.
- `tools` comes from the schema's `tools` key, not the process document, so
  the two cannot drift. `extension_hints` keys are normalized to lowercase
  with a leading dot.
- A service without a `process` key is listed with `process: null`; a
  document that fails validation is listed with `parse_error`. The command
  exits 0 in both cases — a missing or broken convention is visible, never
  silent. Deploy refuses an invalid file, so `parse_error` only appears on a
  record written outside `ast services deploy`. A `process:` on a service
  with no `tools` is refused too: schema consumers read `tools`, and without
  it they would take `process` for a tool.

```json
{"getProcesses": [{
  "process": "fab-package",
  "service_name": "fab-package-automation",
  "persistent_service_id": "ps-…", "service_id": "…", "service_status": "stopped",
  "tools": ["assemble", "validate"],
  "domain": "fab", "label": "…",
  "volume_name": "…", "volume_id": "…",
  "workspace_name": "…", "workspace_id": null,
  "workspace_resolution": {"error": "not_found", "message": "…", "candidates": []},
  "extension_hints": {".zip": ["validate"], ".xlsx": ["assemble"], ".tgz": ["assemble"]},
  "runtime_class": {"assemble": "minutes", "validate": "minutes"},
  "preflight": {"assemble": "self_validating", "validate": "self_validating"},
  "results": {"assemble": {"report_glob": "results/*_report.json"}, "validate": {"report_glob": "results/*_report.json"}},
  "default_inputs": {"validate": {"formats": "md,json"}}
}]}
```

Read-only, no presigned URLs, no local filesystem, no env-backed values in the
output — the posture the gateway's `run_ast` allow-list requires.

## Secrets

Secrets are environment variables injected into your servers — the place to put
API keys and tokens rather than committing them to a repo.

**Values are write-only.** The platform never returns a secret's value, so
`ast secrets get` lists names and scope only. There is no command to read a
value back; if you lose it, replace it with `ast secrets edit`.

### Creating a secret

Pass the value on stdin, from a file, or let the CLI prompt you:

```bash
# From stdin (recommended — keeps the value out of shell history)
echo -n 'sk-abc123' | ast secrets create --name OPENAI_API_KEY \
  --value-stdin --workspace-id <WORKSPACE_ID>

# From a file — use this for multi-line values such as a PEM key
ast secrets create --name GITHUB_APP_PRIVATE_KEY \
  --value-file ./private-key.pem --workspace-id <WORKSPACE_ID>

# Prompt for the value (hidden input)
ast secrets create --name OPENAI_API_KEY --workspace-id <WORKSPACE_ID>
```

`--value <VALUE>` also works, but the value is then visible in your shell
history and in the process list on shared machines. Prefer the options above.

A trailing newline is stripped from `--value-stdin` and `--value-file`, so
`echo` without `-n` behaves as expected.

### Where a secret is visible

Every secret needs somewhere to be exposed — pass one of:

| Flag | Effect |
|------|--------|
| `--workspace-id <ID>` | Expose to that workspace. Repeat for several. |
| `--all-workspaces` | Expose to every workspace in the organization. |

Names are scoped per workspace, not per organization, so the same name can exist
in two workspaces as two independent secrets. Rotating one does not update the
other.

### Bulk import

```bash
ast secrets create --env-file .env --workspace-id <WORKSPACE_ID>
```

One secret per `KEY=VALUE` line. Blank lines, `#` comments, a leading `export `,
and quoted values are handled; for unquoted values a trailing ` # comment` is
stripped, and if a key repeats the last occurrence wins.

**Multi-line values are not supported here** — a PEM key spanning several lines
is rejected rather than truncated. Create those individually with `--value-file`.

### Editing and deleting

```bash
# Replace the value
echo -n 'sk-new' | ast secrets edit --secret-id <SECRET_ID> --value-stdin

# Re-scope without touching the value
ast secrets edit --secret-id <SECRET_ID> --workspace-id <WORKSPACE_ID>

# Delete (prompts for confirmation in an interactive terminal)
ast secrets delete --secret-id <SECRET_ID>
ast secrets delete --secret-id <SECRET_ID> --yes   # skip the prompt
```

Editing cannot rename a secret — delete it and create it again under the new
name.

## Pre-auth

Pre-auth starts a new Agent Studio server already logged in to `gh` and
`claude`. It works by holding your logins as user-scoped `PREAUTH_*` secrets on
the platform and materializing them onto each new server.

That only happens once you are **enrolled** — once the platform actually holds
those secrets. Enrollment is an upload from a server where you are already
logged in, and it never happens automatically: nothing is uploaded without you
asking for it.

**Enrollment is per name, not all-or-nothing.** There are five `PREAUTH_*`
names (the `gh` hosts file, the Claude credentials, the Claude onboarding keys,
`git config --global user.name` and `user.email`), and each one is either held
by the platform, available on this box, or simply not there. A box that seeded
`gh` and `claude` and then gained a git identity has something left to
contribute, and `status` says so.

```bash
# Where is each name? (says NOT ENROLLED when the platform holds nothing)
ast preauth status

# Enrollment, from a server where `gh` and `claude` are logged in
ast preauth seed

# Store only these names — `status` prints the exact line to paste
ast preauth seed --only PREAUTH_GIT_USER_NAME,PREAUTH_GIT_USER_EMAIL

# Re-upload names this box has already seeded
ast preauth seed --overwrite

# Debugging wrappers — the reconcile loop does both every 5 minutes
ast preauth push          # push locally-rotated credentials back to the platform
ast preauth materialize   # pull platform credentials and write them to disk
```

`status` prints the three name lists whenever the API sends them, and then the
invocation that closes the gap:

```
  ENROLLED — the platform holds 2 pre-auth secret(s) for you.
  on platform:                 PREAUTH_CLAUDE_CREDENTIALS_JSON_B64, PREAUTH_GH_HOSTS_YML_B64
  can be stored from this box: PREAUTH_GIT_USER_EMAIL, PREAUTH_GIT_USER_NAME
  not on this box:             PREAUTH_CLAUDE_ONBOARDING_JSON_B64

  2 more can be stored from this box. Run:
    ast preauth seed --only PREAUTH_GIT_USER_EMAIL,PREAUTH_GIT_USER_NAME
```

`--only` is comma-separated and repeatable, and it changes what a missing input
means: with `--only` the caller has already established that those inputs exist,
so one that has gone missing by the time the server reads it is a **skip** and
the command still exits 0. A plain `ast preauth seed` attempts all five, and a
name whose input is missing is a per-name **error** that exits non-zero. A name
outside the five is rejected locally, before any request is made.

`--only` also establishes that the server honours it before uploading anything.
An anasync that does not advertise `enrolment.candidates` on `/preauth/status`
ignores a `names` list and seeds all five, so a selection there would upload
credentials the user never chose. The CLI checks with that read-only request
first and, if the support is not there, refuses ("this server's anasync does not
support per-name seeding; run `ast preauth seed` without --only, or update the
server") without sending the mutation.

`health` follows the same per-name view:

| `health` | Meaning | Enrolled? |
|---|---|---|
| `unenrolled` | the platform holds nothing for you | no |
| `partial` | the platform holds some names, and this box can still contribute others | **yes** |
| `healthy` | the platform holds everything this box has | yes |
| `degraded` | the last pull was incomplete or has not run | unchanged by this |
| `error` | the last pull failed | unchanged by this |
| `disabled` | pre-auth is off for this server | — |

**These commands must run on the server itself.** They talk to the local
anasync API at `http://localhost:8051` (override with `AST_ANASYNC_URL`), not to
the platform API — no platform credential is used and nothing under `~/.ast` is
read or written. Off a server you get:

```
cannot reach anasync API at http://localhost:8051 — this command must run on
the Agent Studio server itself (…)
```

plus the equivalent `curl`, so you can run the request by hand on the right box:

```bash
curl -s http://localhost:8051/preauth/status
curl -s -X POST http://localhost:8051/preauth/seed \
  -H 'Content-Type: application/json' -d '{"overwrite":false}'
curl -s -X POST http://localhost:8051/preauth/push
curl -s -X POST http://localhost:8051/preauth/materialize
```

### Output and exit codes

`ast preauth` is a human diagnostic, so it defaults to a readable summary and
takes its own `--json` flag (the global `--format json` default cannot tell
"asked for JSON" from "said nothing"). On **all four** commands `--json` is a
**projection of the known fields** — the same allow-list the summary prints,
rebuilt from the parsed response rather than passed through. No command echoes
the response body in JSON mode: asking for machine-readable output must not
disable the protection against a field the API adds later.

| Command | What `--json` carries |
|---|---|
| `status` | the parsed status fields, including `enrolment.{candidates,held,missing}`, plus a derived `enrolled` boolean so scripts do not have to re-implement the rule |
| `seed` | `status`, `reason`, `selection` (`requested` with `--only`, else `all`), `attempted` (names), and `seeded` / `skipped` / `errors` as `{name, reason?, fix?}` records |
| `push` | `status`, `reason`, `exit`, and `pushed` / `skipped` as the same records |
| `materialize` | `status`, `message`, `operation_id`, `log_file` |

A body the CLI cannot parse projects to a restricted fallback instead — key
*names*, never values: `{"shapeRecognised": false, "enrolled": null, "known":
{…}, "topLevelKeys": […]}` for `status`, and `{"shapeRecognised": false,
"status": …, "reason": …, "topLevelKeys": […]}` for a mutation. The exit code is
decided from the raw body in either case, so what the projection can read never
changes the verdict. Fields whose type the API may
still change (`platformExpiresAt`, `backoffUntil`, `backoffSeconds`,
`pushedExpiresAt`) are restricted to scalars in both modes — an object or a list
there shows as `(unprintable)` rather than being read into — and a
`state.push.terminal` entry contributes its `reason` string and nothing else. An
HTTP error from anasync is reported as its status code plus, at most, FastAPI's
short `detail` message; the response body is never echoed. A **name list** —
`enrolment.candidates`, `enrolment.held`, `enrolment.missing` and
`state.push.seeded` — is printed one entry at a time through an identifier
guard: a `PREAUTH_*` name starts with `PREAUTH_`, is `[A-Za-z0-9_]` throughout
and is at most 64 characters, so an entry that is not — a token-shaped string
included — shows as `(unprintable)`. That holds in both modes and on the
fallback path, so a field the API repurposes cannot echo through a list this CLI
calls names.

`status` exits 0 whenever the API answered — "not enrolled" is a report, not a
failure. `seed`, `push` and `materialize` decide their exit code from the body
(the endpoints answer HTTP 200 either way) and they read it structurally, not
through the typed parse: a per-name error, an overall status of `error`, a
missing status, or a status this CLI does not recognise all exit non-zero. A
result whose success cannot be established is a failure, never a silent
`unknown` and exit 0. Per-name errors are printed on stderr with the API's own fix
text, e.g.:

```
  error    PREAUTH_GIT_USER_NAME — git config --global user.name is unset
```

Failures print the usual structured envelope on stderr, with
`ANASYNC_UNREACHABLE` for a transport failure and `PREAUTH_FAILED` for
everything else.

### No credential value is ever printed

The anasync state file holds sha256 markers, byte counts and timestamps only —
never a value — and the seed/push endpoints return secret *names* only. The CLI
does not rely on that: **every** output path of **every** `preauth` command is
an allow-list, so a field the API starts returning is never echoed by accident.

| Path | What it prints |
|---|---|
| `status` summary | the fields it knows about: health, enabled, state path, target names, status, sha256 prefix, byte count, `platformExpiresAt`, gitconfig key names, push bookkeeping |
| `status --json` | a projection of those same parsed fields plus `enrolled` — not the response body |
| `status` on an unparseable body | the known keys only (health, enabled, `enabledSource`, `statePath`, `enrolment.{enrolled,promptDue,reason,candidates,held,missing}`, `state.push.{seeded,lastAttempt,lastExit,lastError}`) where they hold a scalar, plus the top-level key *names* — with the name-list paths passed through the identifier guard |
| `seed` / `push` / `materialize` summary | the status, the reason, and per-name records: the name, the API's reason and its fix text |
| `seed` / `push` / `materialize` `--json` | a projection of those same parsed fields (see the table above) — not the response body |
| a mutation on an unparseable body | the `status` and `reason` strings plus the top-level key *names*, with `shapeRecognised: false` |

`preauth` also never resolves a platform credential, including in telemetry:
`ast preauth …` skips the auth-derived identity lookup entirely, so no config
file, token file or keyring is read for it.

## Refresh

`ast refresh` re-syncs the platform-managed resources on an Agent Studio server
— skills, the compiled rules, MCP server configuration and secrets — without
sudo and without restarting the editor. It is the manual equivalent of what
anasync does at startup and whenever the platform says something changed.

Like `preauth`, it talks to the local anasync API on the server itself
(`http://localhost:8051`, override with `AST_ANASYNC_URL`), **not** to the
platform API: no platform credential is used, and nothing under `~/.ast` is
read or written.

```bash
# Everything, in the fixed order below
ast refresh

# One group at a time
ast refresh --skills
ast refresh --rules --mcp-servers

# What would change? Writes nothing, exits 3 when there is drift
ast refresh --check
```

| Flag | What it does |
|---|---|
| `--skills` | re-sync platform skills into `/workspace/skills` |
| `--rules` | re-sync the compiled agent rules and reference docs |
| `--mcp-servers` | re-sync MCP server configuration for every editor |
| `--secrets` | re-sync secrets into `$AST_PATH/.secrets.env` |
| `--all` | all four groups — the default when no group flag is given |
| `--check` | report drift, write nothing (needs anasync-api 0.0.14+) |
| `--url <URL>` | base URL of the local anasync API (env `AST_ANASYNC_URL`) |
| `--timeout <SECS>` | seconds to wait for **one** group (default 120) |
| `--json` | one JSON document instead of the human summary |

**The group order is fixed**, whatever order the flags are given in: `secrets`
→ `mcp-servers` → `rules` → `skills`. MCP server configs resolve
`${secrets.NAME}` at generation time, so stale secrets would otherwise be baked
into `~/.claude.json`, `~/.codex/config.toml` and `~/.gemini/settings.json`;
skills goes last because it downloads and extracts zip packages and is by far
the slowest, so the three cheap groups have already printed before the wait
begins.

```
secrets: success
  OPENAI_API_KEY                 updated
  AWS_ACCESS_KEY_ID              unchanged
  summary: 1 unchanged, 1 updated, 0 added, 0 removed, 0 failed
  NOTE: $AST_PATH/.secrets.env is sourced at shell startup — open a NEW SHELL for these values to be visible. Existing shells and running agents keep the old environment.

mcp-servers: success
  github                         unchanged       ~/.claude.json
  summary: 1 unchanged, 0 updated, 0 added, 0 removed, 0 failed

rules: success
  CLAUDE.md                      unchanged
  summary: 1 unchanged, 0 updated, 0 added, 0 removed, 0 failed

skills: success
  sim-runner                     updated
  job-runner                     unchanged
  summary: 1 unchanged, 1 updated, 0 added, 0 removed, 0 failed

Refreshed 4 of 4 groups — 4 unchanged, 2 updated, 0 added, 0 removed, 0 failed.
```

`--check` computes the same comparison and writes nothing:

```
$ ast refresh --check
skills: success (check)
  sim-runner                     would-update
  job-runner                     unchanged
  summary: 1 unchanged, 1 updated, 0 added, 0 removed, 0 failed

Checked 4 groups — drift in 1 (skills). Nothing was written.
$ echo $?
3
```

**Secrets need a new shell.** `$AST_PATH/.secrets.env` is sourced at shell
startup, so a refreshed value is invisible in the shell that ran the command —
and to every agent already running. `ast refresh` says so whenever the secrets
group ran; open a new shell rather than re-running the refresh.

**Secrets print names and counts, nothing else.** For that group every string
that reaches the output is fixed text, a validated environment variable name, a
count, or a word from a closed vocabulary — never a string anasync sent. An
item `detail`, the group `message`, an HTTP error body, an unrecognised accept
status, the operation id and the log path are all replaced by fixed text
pointing at the anasync operation log, because none of those fields is
established to be value-free. That extends to the request URL — a failing poll
reports `…/operations/<operation id>/status` rather than the id anasync chose,
in the error envelope as well as on stdout. A secret that failed to sync is named, and the
reason is in the log (`/var/log/anasync/`). Every other group keeps its full
detail, including the operation id and the log path — which is why they are
`null` for `secrets` in the `--json` sample above.

**Exit codes**

| Situation | Code |
|---|---|
| every selected group succeeded (in check mode: no drift) | 0 |
| anasync unreachable, any group failed, or `--check` unsupported | 1 |
| check mode, drift found, nothing failed | 3 |

Drift is a report, not a failure: exit 3 prints no error envelope. Script it
with `ast refresh --check; [ $? -eq 3 ]`.

A check summary only says `no drift. Nothing was written.` when every group
completed and confirmed check mode. If a group failed, could not compute the
comparison, or ignored `--check`, the last line says so instead — `Checked 4
groups — 1 could not be checked (skills); drift unknown.` — and the exit code
is 1: an unchecked group is neither clean nor safe to describe as unwritten.

`--timeout` is **per group**, not per command, so the worst case is four times
the value. The default of 120 s is comfortably above the slowest group; a very
large skill set may want `ast refresh --skills --timeout 300`.

`--json` prints one document, rebuilt field by field from what this version
understands — never the response body:

```json
{
  "check": false,
  "exit_code": 0,
  "groups": {
    "secrets": {
      "ok": true, "supported": true, "drift": false, "truncated": false,
      "status": "success",
      "message": "2 secret name(s) reported, 0 failed — diagnostics withheld; see the anasync operation log",
      "operation_id": null, "log_file": null,
      "new_shell_required": true,
      "notice": "NOTE: $AST_PATH/.secrets.env is sourced at shell startup — …",
      "items": [{ "name": "OPENAI_API_KEY", "outcome": "updated", "detail": null }],
      "summary": { "unchanged": 1, "updated": 1, "added": 0, "removed": 0, "failed": 0 },
      "error": null
    }
  },
  "totals": { "unchanged": 1, "updated": 1, "added": 0, "removed": 0, "failed": 0 }
}
```

Group keys use the URL spelling, so the MCP group is hyphenated:
`ast refresh --json | jq '.groups["mcp-servers"].summary'`.

**anasync-api 0.0.14 or newer** is required for `--check` and for per-item
detail. An older server reports the aggregate message per group and says that
per-item detail needs a newer anasync; `--check` against one is refused *before
any request is sent*, because the older API silently ignores the `check`
parameter and would write. The CLI decides this from the `refresh.check` entry
in `capabilities` on `GET /info/version`, never from the version number:
anasync-api 0.0.12 and 0.0.13 shipped without check mode.

**This command only works from a shell on an Agent Studio server.** Anywhere
else it fails with `ANASYNC_UNREACHABLE` and prints the equivalent curl. By
hand, the same thing is:

```bash
curl -s -X POST http://localhost:8051/skills/refresh
curl -s -X POST 'http://localhost:8051/skills/refresh?check=true'
curl -s http://localhost:8051/operations/<operation_id>/status
```

A refresh that anasync is already running is not cancelled: `ast refresh`
starts its own operation and reports what that operation says.

## Rules

Rules are markdown documents that shape how agents behave. They are compiled
into the agent's context when a session starts.

**Hierarchy** (broadest → most specific, more specific overrides broader):
organization → user → service → workspace.

### Reading rules

```bash
ast rules get-organization --organization-id <ORG_ID>
ast rules get-workspace --workspace-id <WORKSPACE_ID>
ast rules get-service --service-id <SERVICE_ID>
ast rules get-user
ast rules get-platform

# Print the markdown itself rather than the JSON envelope
ast rules get-workspace --workspace-id <WORKSPACE_ID> --format table
```

### Writing rules

Each `edit-*` subcommand takes the markdown from **either** `--rules` or
`--rules-file` — exactly one, never both:

```bash
# From a file (easiest for a whole document)
ast rules edit-organization --organization-id <ORG_ID> --rules-file rules.md

# Inline
ast rules edit-workspace --workspace-id <WORKSPACE_ID> --rules '# Rules

Prefer small commits.'
```

The content is sent **literally**. It is not parsed as JSON, so markdown,
backticks, and quotes need no escaping — do *not* pre-encode with `jq -Rs .`,
or the quotes and `\n` escapes will be stored as literal characters.

A single trailing newline is stripped from `--rules-file`, so
`--rules-file x.md` and `--rules "$(cat x.md)"` send identical content.

**`edit-*` replaces the whole document**, it does not append. Read the current
rules first if you mean to extend them:

```bash
ast rules get-workspace --workspace-id <WS_ID> --format table > rules.md
# edit rules.md
ast rules edit-workspace --workspace-id <WS_ID> --rules-file rules.md
```

Empty rules are rejected, so a write cannot silently blank out the document
agents rely on.

## Global Options

| Flag | Description | Default |
|------|-------------|---------|
| `--format <json\|table>` | Output format | `json` |
| `--env <ENV>` | Target environment | `prod` |
| `--api-key <KEY>` | API key | — |
| `--bearer-token <TOKEN>` | Bearer token | — |
| `-v, --verbose` | Enable verbose logging | off |

`preauth` and `refresh` are the exceptions to `--format`: both default to a
human summary and take their own `--json` flag (see [Pre-auth](#pre-auth) and
[Refresh](#refresh)).

## Configuration

Config is stored at `~/.ast/config.yaml`:

```yaml
apikey: <your-api-key>
environment: <last-used-auth-url>
```

| Environment variable | Description | Default |
|---|---|---|
| `AST_ANASYNC_URL` | Base URL of the local anasync API used by `ast preauth` and `ast refresh` (server-only; the request never goes through an egress proxy) | `http://localhost:8051` |

## License

MIT
