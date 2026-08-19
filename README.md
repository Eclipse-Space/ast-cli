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
```

Further command groups: `organizations`, `members`, `volumes`, `volume-data`,
`services`, `skills`, `servers`, `mcp-servers`, `api-keys`, `rules`, `schema`.
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

## Configuration

Config is stored at `~/.ast/config.yaml`:

```yaml
apikey: <your-api-key>
environment: <last-used-auth-url>
```

## License

MIT
