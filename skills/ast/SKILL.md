---
name: ast
description: Use when an agent needs to interact with the Eclipse Agent Studio platform — authentication, workspace management, creating servers, running service jobs, managing data in volumes, skills, MCP servers, and more.
argument-hint: [optional: command context like "login", "create workspace", "run lens design job", etc.]
---

# Eclipse Agent Studio

Agent Studio is a cloud platform for AI-assisted development. Users configure **workspaces** that bundle tools (services), data (volumes), behavior rules, and MCP integrations. From a workspace, users launch **servers** — cloud development environments with a built-in IDE and AI agent (Claude Code). Services are developed, tested, deployed and used **on** servers. Service jobs run **within** workspace context. Volumes mount **to** servers for persistent, shared storage.

---

# 1. Install the CLI

Before running any command, determine which binary to use:

```bash
# 1. Already on PATH
if command -v ast >/dev/null 2>&1; then
    CLI="ast"
# 2. Claude Code skill directory
elif [ -f "$HOME/.claude/skills/ast/bin/ast" ]; then
    CLI="$HOME/.claude/skills/ast/bin/ast"
# 3. Gemini skill directory
elif [ -f "$HOME/.gemini/skills/ast/bin/ast" ]; then
    CLI="$HOME/.gemini/skills/ast/bin/ast"
# 4. Codex skill directory
elif [ -f "$HOME/.codex/skills/ast/bin/ast" ]; then
    CLI="$HOME/.codex/skills/ast/bin/ast"
# 5. Legacy default install location
elif [ -f "$HOME/.local/bin/ast" ]; then
    CLI="$HOME/.local/bin/ast"
# 6. Install from GitHub
elif curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install.sh | bash; then
    CLI="$HOME/.local/bin/ast"
# 7. Offline fallback — build from source (requires git + cargo)
elif command -v cargo >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/cargo" ]; then
    CARGO="${HOME}/.cargo/bin/cargo"
    command -v cargo >/dev/null 2>&1 && CARGO="cargo"
    git clone https://github.com/Eclipse-Space/ast-cli /tmp/agent-studio-cli 2>&1
    cd /tmp/agent-studio-cli
    $CARGO build --release 2>&1
    CLI="/tmp/agent-studio-cli/target/release/ast"
else
    echo "ERROR: Cannot install ast." >&2
    echo "" >&2
    echo "All install methods failed. To build from source, install the following dependencies:" >&2
    echo "  1. git    — https://git-scm.com/downloads" >&2
    echo "  2. cargo  — curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
    echo "" >&2
    echo "Then re-run this script, or build manually:" >&2
    echo "  git clone https://github.com/Eclipse-Space/ast-cli /tmp/agent-studio-cli" >&2
    echo "  cd /tmp/agent-studio-cli && cargo build --release" >&2
    echo "  cp target/release/ast ~/.local/bin/" >&2
    exit 1
fi
```

Use `$CLI` in place of `ast` in all commands below.

## Global Options

These apply to every command:

| Option | Description | Default |
|--------|-------------|---------|
| `--format <json\|table>` | Output format | `json` |
| `--env <prod\|staging\|dev\|local>` | Target environment (env: `AST_ENVIRONMENT`) | `prod` |
| `--api-key <KEY>` | API key, overrides config (env: `AST_API_KEY`) | — |
| `--bearer-token <TOKEN>` | Bearer token, overrides API key (env: `AST_BEARER_TOKEN`) | — |
| `-v, --verbose` | Debug logging | off |
| `AST_ANASYNC_URL` (env only) | Base URL of the local anasync API used by `preauth` and `refresh` — server-only, no platform credential | `http://localhost:8051` |

Auth priority: `--bearer-token` > `--api-key` > config file > keychain token.

`--format` applies everywhere except the `preauth` group and `refresh`, which
are human diagnostics: both default to a readable summary and take their own
`--json` flag.

---

# 2. Authentication

Both `auth login` and `auth register` use a two-phase OAuth pattern. **This is the first step for any new user.**

## CRITICAL: Always run the background task BEFORE presenting the URL to the user

```
Phase 1: run auth login / auth register  →  exits immediately, prints [INSTANCE_ID] [WAIT_TOKEN]
Phase 2: start auth callback in background IMMEDIATELY  →  blocks on SSE until tokens arrive
Then:    present the URL to the user  →  wait for background task completion notification
```

**Do NOT:**
- Tell the user to "let me know when you've logged in" — the background task handles this automatically
- Ask the user for confirmation before starting the callback — start it immediately after Phase 1
- Poll or check task status manually — you will be notified automatically when it completes

**Do:**
- Start `auth callback` in the background immediately after parsing Phase 1 output
- Present the URL to the user in a friendly, simple way (no raw labels or tech details)
- Wait silently — when the background task completes you are notified automatically
- Read the task output immediately when notified (before doing anything else)

---

## auth login — Existing Account

### Phase 1: Initiate Login

Run synchronously (not in background) — it exits immediately:

```bash
$CLI auth login 2>&1
```

#### Expected Output

```
[AUTH_URL] https://keycloak.example.com/realms/eclipse/protocol/openid-connect/auth?client_id=...
[INSTANCE_ID] xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[WAIT_TOKEN] yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
[ACTION] Start `auth callback --instance-id xxx --wait-token yyy` in the background, then present AUTH_URL to the user...
```

### Phase 2: Complete Login (Callback)

Start this **immediately after Phase 1, in the background** — before presenting the URL to the user:

```bash
$CLI auth callback \
  --instance-id <INSTANCE_ID_FROM_PHASE_1> \
  --wait-token <WAIT_TOKEN_FROM_PHASE_1> \
  2>&1
```

Use `run_in_background: true` (Bash tool) so the agent continues while the callback waits on SSE.

### Phase 2 Alternative: Non-blocking Status Check

If your client **cannot run background processes**, use `auth status` instead of `auth callback`. It makes a single GET request and returns immediately:

```bash
$CLI auth status \
  --instance-id <INSTANCE_ID_FROM_PHASE_1> \
  --wait-token <WAIT_TOKEN_FROM_PHASE_1> \
  2>&1
```

- `[AUTH_COMPLETE]` — tokens stored, user is authenticated (exit code 0)
- `[AUTH_WAITING]` — user hasn't completed browser flow yet (exit code non-zero)
- `[AUTH_FAILED]` — error occurred (exit code non-zero)

Call `auth status` on your own schedule — retry until you get `[AUTH_COMPLETE]` or `[AUTH_FAILED]`.

### Agent Flow

1. Run `auth login` synchronously — parse `[AUTH_URL]`, `[INSTANCE_ID]`, `[WAIT_TOKEN]`
2. **Immediately** start `auth callback --instance-id <ID> --wait-token <TOKEN>` in the background (or use `auth status` if background processes are unavailable)
3. Present the login link to the user (see "Presenting to the User" below)
4. Do NOT poll — you will be automatically notified when the background task completes
5. **Immediately read the task output when notified** — before doing anything else
6. Parse `[AUTH_USER]` and tell the user they're logged in

### If Manager Relay Fails

If you see `Warning: Manager relay login failed`, the CLI fell back to the paste-URL flow:

1. Tell the user to open the `[AUTH_URL]`
2. After login, the browser redirects to `http://localhost:9090/?code=...` (page won't load)
3. The user copies that full URL and pastes it into the terminal

---

## auth register — New Account

### Phase 1: Initiate Registration

```bash
$CLI auth register 2>&1
```

#### Expected Output

```
[REGISTER_URL] https://deckard.example.com/register-as/?source=cli&instanceId=xxx&loginUrl=<encoded>
[INSTANCE_ID] xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[WAIT_TOKEN] yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
```

### Phase 2: Same `auth callback` (or `auth status`) command as login

### Agent Flow

1. Run `auth register` synchronously — parse `[REGISTER_URL]`, `[INSTANCE_ID]`, `[WAIT_TOKEN]`
2. **Immediately** start `auth callback --instance-id <ID> --wait-token <TOKEN>` in the background (or use `auth status` if background processes are unavailable)
3. Present the registration link to the user
4. Do NOT poll — you will be automatically notified when the background task completes
5. **Immediately read the task output when notified** — before doing anything else
6. Parse `[AUTH_USER]` and tell the user they're registered and logged in

### What the User Does in the Browser

1. Opens `[REGISTER_URL]` → Deckard registration form
2. Fills in name, email, password, optional organization → clicks "Create account"
3. Lands on verify email page — checks inbox, clicks the verification link
4. Returns to the verify page (keep this tab open) → clicks **"Continue to Login"**
5. Keycloak login page → logs in with their new credentials
6. Browser shows authentication success page — done

> **Note on email verification:** The verification link in the email goes to Keycloak,
> not back to the Deckard verify page. The user should keep the Deckard verify tab open
> so they can click "Continue to Login" after verifying.

---

## Expected Callback Output (for both login and register)

```
[AUTH_USER] c w (user@example.com) | MyOrg
[AUTH_COMPLETE] Tokens stored. You are authenticated.
```

If the output is unavailable when notified (file cleaned up), fall back to:
```bash
$CLI auth whoami 2>&1
```

---

## Presenting to the User

**IMPORTANT:** The labeled output (`[AUTH_URL]`, `[REGISTER_URL]`, `[INSTANCE_ID]`, etc.) is
for the agent to parse — never show raw labels or technical details to the user.

**For login — before:** show the user something like:

> Please open this link to log in:
>
> https://keycloak.example.com/realms/...
>
> I'm waiting in the background — you'll be signed in automatically once you complete the browser flow.

**For register — before:** show something like:

> Please open this link to create your account:
>
> https://deckard.example.com/register-as/...
>
> After signing up, check your email and click the verification link. I'm waiting in the background — you'll be signed in automatically once you're done.

**After login/register — parse `[AUTH_USER]` and show:**

> You're logged in as c w (user@example.com) on the MyOrg organization.

Keep it simple — no instance IDs, wait tokens, phases, or JSON dumps.

---

## Auth Error Cases

| Output | Meaning |
|--------|---------|
| `AST_MANAGER_URL is not set` | Should not occur with prod defaults — set `AST_ENVIRONMENT=prod` |
| `AST_DECKARD_URL is not set` | Should not occur with prod defaults (register only) |
| `Manager relay returned error` | Management server rejected the request |
| `Invalid wait token — access denied` | Wrong wait_token — re-run Phase 1 |
| `Session expired or not found` | Took too long — re-run Phase 1 |
| `Timed out waiting for authentication` | User didn't complete browser flow within 15 min |
| `Auth failed: Token exchange with Keycloak failed` | Server-side PKCE exchange failed |

## Auth Troubleshooting

- **"Keycloak OAuth is not configured on this server"** — Management server missing `KEYCLOAK_ISSUER` or `KEYCLOAK_CLI_REDIRECT_URI` env vars.
- **"Manager relay request failed: connection refused"** — Management server not running or wrong `AST_MANAGER_URL`. Check: `curl -s $AST_MANAGER_URL/health`
- **"Invalid redirect_uri"** — Manager's callback URL needs to be added to Keycloak `deckard` client's "Valid redirect URIs".
- **Fallback: Direct PKCE Flow** — `export AST_MANAGER_URL="" && $CLI auth login 2>&1`

---

## Auth Architecture (same for both login and register)

```
Agent                   Management Server              Keycloak / Deckard
  |                           |                           |
  | Phase 1: auth login/register                          |
  |-- POST /cli-auth -------->|                           |
  |<-- { url, instanceId,     |                           |
  |      waitToken }          |                           |
  |                           |                           |
  | print [URL] [INSTANCE_ID] [WAIT_TOKEN] → exit Phase 1|
  |                           |                           |
  | Phase 2: auth callback (background)                   |
  |== GET /events/:id =======>| (SSE connection held open)|
  |    ?token=waitToken       |                           |
  |                           |                           |
  | [present URL to user]                                 |
  |                           |                           |
  |  [user opens url in browser] ----------------------->|
  |  [user completes flow]                                |
  |                           |<-- GET /callback?code= ---|
  |                           |-- POST /token (PKCE) ---->|
  |                           |<-- { access_token } ------|
  |                           |                           |
  |<== SSE push: { success,   | (instant delivery)        |
  |     token, refreshToken } |                           |
  |                           |                           |
  | stores tokens, sets org   |                           |
  | background task exits 0   |                           |
  | → agent notified → tells user they're authenticated   |
```

---

# 3. Onboarding the User

After authentication, get the user into a running server as fast as possible. **The server URL is the deliverable of onboarding — not the workspace ID.** Do not explain all platform concepts upfront. Do not list all available features. Do not ask "what would you like to do next?" — the next step is always: open the IDE.

## Post-Auth Checklist (follow this exactly)

### Step 1: Confirm organization context

1. Run `organizations get --format table`
2. If the user belongs to **multiple organizations**, list them and ask which one to use
3. Switch if needed with `organizations use --organization-id <ORG_ID>`

**Do not skip this step.** If you default to the wrong org, everything downstream is wrong.

**Important:** Once the organization is confirmed, use `--organization-id <ORG_ID>` on all subsequent commands to scope results to that org. Without it, queries return resources across ALL organizations the user belongs to.

### Step 2: Find or create a workspace

1. Run `workspaces get --organization-id <ORG_ID> --format table`
2. If the user **has workspaces**, ask which one they want to use (or if they want a new one)
3. If the user **has no workspaces**, offer two paths:
   - **"Explore an example"** — point them to the examples marketplace: `https://studio.eclipse.space/<organizationId>/examples/workspaces/`
   - **"Start fresh"** — create a new workspace with `workspaces create`
4. If creating a new workspace, ask only for a name and brief description — keep it simple

### Step 3: Get the server URL (this is the goal)

1. Run `servers get --format table`
2. Find the server associated with the workspace (a server auto-starts when a workspace is created)
3. If the server is running, construct the URL: `https://<editorId>.tyrell-proxy.studio.eclipse.space/#/workspace`
4. If the server is stopped, start it with `servers start --editor-id <EDITOR_ID>`, then construct the URL
5. **Present the server URL to the user immediately.** This is the deliverable.

### Step 4: Hand off

After giving the URL, say something like:

> Your workspace "lens-design" is ready, and a server is running for you.
>
> Open your IDE here:
> https://ed-1234567890.tyrell-proxy.studio.eclipse.space/#/workspace
>
> Once you're in, your AI assistant can help you find and use services, work with data, and more.

**Do NOT:**
- List all platform features or available commands
- Ask "what would you like to do next?" — the next step is opening the IDE
- Show workspace IDs, org IDs, or other technical details unless the user asks

**Do:**
- Make the URL prominent and clickable
- Keep the message short and actionable
- Signal that more capabilities are available inside the IDE without listing them all

## Example: Ideal Onboarding Interaction

```
User: Can you help me get started with Eclipse Agent Studio?

Agent: [resolves CLI, checks auth — already logged in]

       Welcome back, Ethan! You're authenticated.

       You belong to multiple organizations:
       - Eclipse Agent Studio
       - Nullspace

       Which organization would you like to work in?

User: Eclipse Agent Studio

Agent: [switches org, checks workspaces — none found]

       You don't have any workspaces yet in this org.
       Would you like to create a new one, or explore an example
       workspace from the marketplace?

User: Create a new one for lens design

Agent: [creates workspace, checks servers, constructs URL]

       Your workspace "lens-design" is ready, and a server is
       running for you.

       Open your IDE here:
       https://ed-1773262942743.tyrell-proxy.studio.eclipse.space/#/workspace

       Once you're in, your AI assistant can help you find and use
       services, work with data, and more.
```

Notice: no feature dump, no "what next?", no IDs shown. The user goes from zero to a running IDE in four exchanges.

## After Onboarding: Teach by Doing

Once the user is on a server, introduce concepts **only when the user's current task requires it**:

| User wants to... | Introduce... | How |
|---|---|---|
| Work with data or files | **Volumes** | Create/upload a volume, attach to workspace, show mount path |
| Use a tool or run a job | **Services** | Browse available services, attach one, run a job with it |
| Change how the AI behaves | **Rules** | Show current rules, edit workspace rules |
| Connect external tools (Slack, GitHub, etc.) | **MCP Configs** | Add an MCP server config to the workspace |
| Store API keys securely | **Secrets** | `secrets create --value-stdin --workspace-id <ID>`, explain it becomes an env var |
| Build a custom tool | **Service development** | Walk through scaffold → build → test → deploy on the server |
| Share with teammates | **Members** | Add members to the org or share workspace access |
| Reuse prompts or workflows | **Skills** | Explain skills, show how to create or attach one |

**Always frame concepts in terms of the user's goal**, not as abstract platform features. For example:
- Good: "To get your data onto the server, we'll create a volume — think of it as a shared folder."
- Bad: "Volumes are persistent storage containers that can be shared across workspaces."

## If the User Asks for a Tour

If the user explicitly asks to understand the platform or wants a walkthrough, suggest they start with an **example workspace** from the marketplace. Example workspaces come pre-configured with services, volumes, and rules — so the user can see everything working together before learning the individual pieces.

Walk them through what's already set up:
1. "This workspace has **service X** attached — that's a tool the AI can run for you."
2. "It has a **volume** mounted with sample data — you'll find it at `/workspace/volumes/<name>/`."
3. "The **workspace rules** are set to guide the AI to focus on Y."

Learning by inspecting a working example is more effective than reading definitions.

---

# 4. Understanding the Platform

Reference material for the agent — the concepts and URL patterns needed to help users effectively.

## Platform Hierarchy

```
Organization
├── Members (roles: admin, member)
├── Organization Services (containerized tools, shared catalog)
├── Organization Volumes (shared storage across workspaces)
├── Organization Rules (company-wide agent behavior)
├── Organization MCP Configs (company-wide mcp configurations)
├── Organization Agent Skills (company-wide shared skills)
├── Organization Secrets (shared env vars)
└── Organization Workspaces (project configurations)
     ├── Workspace Services → agent can invoke their tools
     ├── Workspace Volumes → mounted to servers
     │   ├── Workspace Volume (auto-created, scoped to workspace)
     │   └── Organization Volumes (explicitly attached)
     ├── Workspace Rules (project-specific agent guidance)
     ├── Workspace MCP Configs + overrides
     ├── Workspace Secrets (project-specific env vars)
     └── Workspace Servers (cloud dev environments, 1+ per workspace)
          ├── Configured Agent (Tyrell - browser only, Claude Code, Codex, Gemini, etc.)
          │   ├── Agent Context (primed with combined rules)
          │   ├── Agent MCP (ability to run service jobs, develop services, update rules, use custom MCPs, etc.)
          │   └── Agent Skills (reusable prompt packages that extend agent capabilities for specific tasks)
          ├── Web IDE (browser, no setup needed)
          ├── Desktop IDE (VS Code, Cursor, Windsurf via SSH)
          ├── Mounted volumes at /workspace/volumes/<volume-name>/
          ├── Injected secrets as environment variables
          └── Docker runtime for service development
```

### Key Concepts

- **Organizations** are shared team spaces on the platform. Members share services, volumes, rules, and billing. Users can belong to multiple organizations — always confirm the user is operating in the correct org context before taking actions (use `organizations get` to list, `organizations use` to switch).
- **Workspaces** are configurations — they define what tools, data, and rules are available. Creating a workspace auto-starts a new server.
- **Servers** are where all work happens. Services are used here, volumes are accessible here, the AI agent runs here. Think of them as cloud dev machines.
- **Services** are containerized tools with defined inputs/outputs that agents can invoke. They must be attached to a workspace before use or developed on the server. Two types: **standard** (run on-demand on the server, terminate after) and **persistent** (run continuously on its own server).
- **Volumes** are persistent storage shared across servers/workspaces. Organization volumes can be shared; workspace volumes are auto-created and scoped. Mount path: `/workspace/volumes/<volume-name>/`.
- **Rules** are text instructions compiled into the agent's context at startup. Hierarchy (broadest → most specific): Organization → User → Service → Workspace.
- **MCP Configs** extend agent capabilities by connecting additional MCP servers. Organization-level configs start disabled per workspace; user and workspace configs start enabled.
- **Secrets** are environment variables injected into servers, useful for API keys.
- **Examples Marketplace** provides pre-built example workspaces, services, volumes, and rules to help users get started quickly.

---

## URL Patterns & Entity Resolution

### Deckard UI URLs (Web Dashboard)

| Resource | URL Pattern |
|----------|-------------|
| Organization home | `https://studio.eclipse.space/<organizationId>/` |
| Workspace | `https://studio.eclipse.space/<organizationId>/workspaces/<workspaceId>/` |
| Volume | `https://studio.eclipse.space/<organizationId>/volumes/<volumeId>/` |
| Examples (main) | `https://studio.eclipse.space/<organizationId>/examples/` |
| Example workspaces | `https://studio.eclipse.space/<organizationId>/examples/workspaces/` |

### Server URLs (Browser IDE)

| Resource | URL Pattern |
|----------|-------------|
| Web IDE | `https://<editorId>.tyrell-proxy.studio.eclipse.space/#/workspace` |

### ID Formats

All entity IDs (organization, workspace, volume, service, editor) use UUID format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### Extracting IDs from User-Provided URLs

When a user provides a URL, parse out the relevant IDs:

| URL | Extracted IDs |
|-----|---------------|
| `https://studio.eclipse.space/abc123-…/workspaces/def456-…/` | organizationId=`abc123-…`, workspaceId=`def456-…` |
| `https://studio.eclipse.space/abc123-…/volumes/ghi789-…/` | organizationId=`abc123-…`, volumeId=`ghi789-…` |
| `https://xyz789-….tyrell-proxy.studio.eclipse.space/#/workspace` | editorId=`xyz789-…` |

### Validating User Input

If a user provides a URL that doesn't match the patterns above:
1. Explain the expected URL format for what they're trying to do
2. Ask them to copy the URL from their browser address bar while on the relevant page in Deckard
3. Or use `$CLI workspaces get --format table` / `$CLI servers get --format table` to look up the correct IDs

**Never guess or fabricate IDs.** Always verify with the CLI or ask the user.

---

# 5. Common Workflows

## Onboarding — New User

```bash
# Register and authenticate
$CLI auth register       # two-phase flow (see Auth section above)
$CLI auth whoami         # verify identity

# Explore the platform
$CLI organizations get --format table   # see your org(s)
$CLI workspaces get --format table      # list workspaces

# Point user to the examples marketplace for getting started:
# https://studio.eclipse.space/<organizationId>/examples/workspaces/
```

After registration, guide the user to create their first workspace or explore example workspaces in the marketplace.

## Onboarding — Existing User

```bash
$CLI auth login          # two-phase flow (see Auth section above)
$CLI auth whoami         # verify identity
$CLI workspaces get --format table   # list workspaces
$CLI servers get --format table      # check server status
```

If the user provides a Deckard URL, parse the IDs (see URL Patterns above) and use them directly.

## Full Workflow: Workspace → Server → Work

```bash
# 1. Create workspace (auto-starts a server)
$CLI workspaces create \
  --organization-id <ORG_ID> \
  --name "My Workspace" \
  --description "Description"

# 2. Attach services to the workspace
$CLI services get --format table                # browse services; Tags and Category (label) columns show each service's labels
# for tag lookups use the default JSON (tags, category, categoryLabel), e.g. | jq '.getServices[] | select(.tags | index("cfd"))'
$CLI services add-to-workspace \
  --workspace-id <WS_ID> \
  --service-ids <SERVICE_ID>

# 3. Attach volumes to the workspace
$CLI volumes get --organization-id <ORG_ID> --format table   # list volumes
$CLI volumes add-to-workspace \
  --workspace-id <WS_ID> \
  --volume-ids <VOL_ID>

# 4. Check server status (one was auto-created with the workspace)
$CLI servers get --format table

# 5. If no running server, start one
$CLI servers start --editor-id <EDITOR_ID>

# 6. User opens the IDE:
#    Browser: https://<editorId>.tyrell-proxy.studio.eclipse.space/#/workspace
#    Desktop: VS Code / Cursor / Windsurf via SSH (requires SSH keys in Profile)

# 7. From within the IDE, the agent can:
#    - Develop services (Docker build/test/deploy)
#    - Run service jobs
#    - Access volume data at /workspace/volumes/<volume-name>/
#    - Use all attached services as tools
```

## Create and Upload to a Volume

```bash
# Create an organization volume
$CLI volumes create \
  --organization-id <ORG_ID> \
  --name "My Data"

# Upload files (multipart + resumable above 50 MiB; re-run to resume after an interruption)
$CLI volume-data upload \
  --volume-id <VOL_ID> \
  --file /path/to/file.json \
  --key results/file.json

# Download files (nested keys work; directory structure is preserved under
# --output-dir since 0.1.4 — pass --flat for the old basename-only layout)
$CLI volume-data download \
  --volume-id <VOL_ID> \
  --keys sim-runner/jobs/<SIM_ID>/results/out.bin \
  --output-dir ./results

# Presign for external tools (bare URL on stdout with --format table; expires in 24 h)
aria2c -x16 "$($CLI volume-data presign --volume-id <VOL_ID> --key results/out.bin --format table)"

# Attach to workspace (makes it available on servers at /workspace/volumes/My Data/)
$CLI volumes add-to-workspace \
  --workspace-id <WS_ID> \
  --volume-ids <VOL_ID>
```

## Run a Service Job

```bash
# Ensure service is attached to the workspace first
$CLI services add-to-workspace \
  --workspace-id <WS_ID> \
  --service-ids <SERVICE_ID>

# Submit job with payload
$CLI service-jobs create \
  --workspace-id <WS_ID> \
  --service-id <SERVICE_ID> \
  --payload '{"tool": "tool_name", "inputs": {"param1": "value1"}}'

# Check job status
$CLI service-jobs get --workspace-id <WS_ID> --format table
```

**Payload format:** `{"tool": "<tool_name>", "inputs": {<parameters>}}` — always include `"inputs"` even if empty.

## Run a Persistent-Service Job (e.g. a solver)

```bash
# Which process runs where — persistent service, store volume, jobs workspace,
# tools — with this environment's ids (never copy ids from a document)
$CLI processes get --organization-id <ORG_ID>
$CLI processes get --extension .aedt   # by input file type

# Discover the service and its tools
$CLI persistent-services get --workspace-id <WS_ID> --format table
$CLI persistent-services get --persistent-service-id <PS_ID> --format table

# Submit — volume paths in inputs use the volume UUID; queues even if stopped
$CLI persistent-services jobs create \
  --persistent-service-id <PS_ID> \
  --workspace-id <WS_ID> \
  --volumes <VOLUME_UUID> \
  --payload '{"tool": "hfss_solve", "inputs": {"project_file": "/workspace/volumes/<VOLUME_UUID>/in.aedt"}}'

# Poll until completedAt is set (single-shot per call; exit 0 even on failure;
# JSON output is the job object itself — check .completedAt)
$CLI persistent-services jobs status --ps-job-id <PS_JOB_ID> --workspace-id <WS_ID>

# Terminal jobs expose presigned log/result URLs (~24 h; re-query to refresh)
$CLI persistent-services jobs status --ps-job-id <PS_JOB_ID> --workspace-id <WS_ID> --format table
```

## Service Development Lifecycle (on a server)

Services are developed **on servers** inside the IDE:

1. **Scaffold** — Use templates from `~/.agent-studio/templates` or ask the agent
2. **Configure** — Edit `service.yaml` (name, description, tools, inputs, outputs; optional top-level `rules:` for the agent-facing document and `process:` for the `process.yaml` discovery block that `processes get` reads)
3. **Implement** — Write tool handlers, `entrypoint.py`, Dockerfile
4. **Build** — `docker build -t my-service -f .devcontainer/Dockerfile .`
5. **Test locally** — `docker run -e payload='{"tool":"...","inputs":{...}}' -v /workspace:/workspace -u $(id -u):$(id -g) my-service`
6. **Deploy** — Via agent deploy tool or `anadeploy` CLI

GPU support: add `--gpus all` to docker run. Mount source code for rapid iteration without full rebuilds.

---

# 6. CLI Reference

## auth — Authentication

| Command | Required Options | Description |
|---------|-----------------|-------------|
| `auth login` | — | OAuth2 PKCE login (two-phase, see above) |
| `auth logout` | — | Clear stored credentials |
| `auth whoami` | — | Show current user info |
| `auth register` | — | Register new account (two-phase, see above) |
| `auth callback` | `--instance-id`, `--wait-token` | Complete two-phase auth (run in background) |
| `auth status` | `--instance-id`, `--wait-token` | Non-blocking auth check (single request, returns immediately) |

Options for `auth login`: `--interactive` (open browser directly).

## organizations — Organization management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `organizations get` | — | `--organization-id`, `--limit` (50), `--cursor`, `--fields` |
| `organizations edit` | `--organization-id`, `--name` | — |
| `organizations use` | — | `--organization-id` or `--interactive` (one required) |

## workspaces — Workspace management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `workspaces get` | — | `--organization-id`, `--workspace-id`, `--limit` (50), `--cursor`, `--fields`, `--filters` |
| `workspaces create` | `--organization-id`, `--name` | `--description`, `--tags` |
| `workspaces edit` | `--workspace-id` | `--name`, `--description`, `--tags` |
| `workspaces delete` | `--workspace-id` | — |

## members — Member management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `members get` | `--organization-id` | `--limit` (50), `--cursor` |
| `members add` | `--organization-id`, `--email`, `--role` | — |
| `members remove` | `--organization-id`, `--email` | — |
| `members edit` | `--organization-id`, `--email`, `--role` | — |

Role values: `admin`, `member`.

## volumes — Volume management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `volumes get` | — | `--organization-id`, `--workspace-id`, `--volume-id`, `--limit` (50), `--cursor`, `--fields`, `--filters` |
| `volumes create` | `--organization-id`, `--name` | `--description`, `--permission` (`private`\|`organization`), `--tags` |
| `volumes edit` | `--volume-id` | `--name`, `--description`, `--permission`, `--tags` |
| `volumes delete` | `--volume-id`, `--organization-id` | — |
| `volumes add-to-workspace` | `--workspace-id` | `--volume-ids` |
| `volumes remove-from-workspace` | `--workspace-id` | `--volume-ids` |

## volume-data — Volume data operations

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `volume-data get` | `--volume-id` | `--keys` (exact lookup, repeatable), `--dir`, `--recursive` (`true`\|`false`), `--limit` (50), `--cursor` |
| `volume-data upload` | `--volume-id`, `--file` | `--key`, `--no-resume` |
| `volume-data download` | `--volume-id`, `--keys` (repeatable) | `--output-dir`, `--flat` |
| `volume-data delete` | `--volume-id` | `--keys` |
| `volume-data presign` | `--volume-id`, `--key` | `--method` (`get`\|`put`, default `get`), `--size` (bytes, required for `put`) |
| `volume-data finalize` | `--key` | `--upload-id`, `--part <n>:<eTag>` (repeatable) |

Notes:
- Uploads stream in 50 MiB parts; files above 50 MiB use multipart with a resume
  checkpoint under `~/.ast/uploads/` — an interrupted upload picks up where it
  left off on re-run (`--no-resume` forces a fresh start).
- Downloads look up keys exactly (nested keys like `sim-runner/jobs/<id>/results/x`
  work), stream to disk, and preserve the key's directory structure under
  `--output-dir` (since 0.1.4). `--flat` restores the pre-0.1.4 layout: every
  file lands directly in `--output-dir` under its basename.
- `presign --format table` prints the bare URL(s) on stdout for shell composition,
  e.g. `aria2c -x16 "$($CLI volume-data presign --volume-id <V> --key <K> --format table)"`.
  Download URLs expire after 24 h. For multipart PUT sizes, table format prints
  one part URL per line on stdout with `uploadId`/`partSize` and the finalize
  command on stderr. `--format json` (default) returns the full contract; for
  multipart PUT it includes `urls[]`, `partSize`, `uploadId`, and the exact
  `finalize` command to run afterwards.
- `finalize` registers an object uploaded via presigned PUT — until it runs, the
  object does not appear in `volume-data get`. Uploads via `volume-data upload`
  finalize automatically.

## services — Service management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `services get` | — | `--organization-id`, `--workspace-id`, `--service-id`, `--limit` (50), `--cursor`, `--fields`, `--filters` |
| `services create` | `--organization-id`, `--service-type-id`, `--name` | `--description`, `--instance`, `--tags` |
| `services edit` | `--service-id` | `--name`, `--description`, `--instance`, `--tags` (replace all), `--add-tag`, `--remove-tag` (repeatable; not with `--tags`), `--category <slug>`, `--clear-category` |
| `services delete` | `--service-id` | — |
| `services deploy` | `--service-id` unless the service file has a remote saved for the target `--env` (one remote per environment; a missing or ambiguous match is refused, never guessed) | `--service`, `--path`, `--dockerfile`, `--noninteractive`, `--log-file`, `--no-push`, `--no-poll` |
| `services types` | — | — |
| `services instance-types` | — | — |
| `services add-to-workspace` | `--workspace-id` | `--service-ids` |
| `services remove-from-workspace` | `--workspace-id` | `--service-ids` |

**Service types:**
- **Standard** — run on-demand, complete task, terminate. Good for batch processing and isolated jobs.
- **Persistent** — run continuously alongside servers, maintain state. Good for APIs and stateful operations.

## service-jobs — Service job management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `service-jobs get` | — | `--workspace-id`, `--service-id`, `--limit` (50), `--cursor`, `--fields`, `--filters` |
| `service-jobs create` | `--workspace-id`, `--service-id` | `--payload` (JSON string), `--payload-file` (path) |
| `service-jobs delete` | `--workspace-id`, `--job-id` | — |

## persistent-services — Persistent service management (lifecycle + jobs)

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `persistent-services get` | — | `--persistent-service-id` (detail view incl. tools), `--organization-id`, `--workspace-id`, `--limit` (50), `--cursor`, `--fields` (GraphQL selection, e.g. `name,persistentServiceId,status` — the default record carries `serviceSchema` + `serviceRules`, tens of KB per service) |
| `persistent-services start` | `--persistent-service-id` | — |
| `persistent-services stop` | `--persistent-service-id` | — |
| `persistent-services restart` | `--persistent-service-id` | — |
| `persistent-services jobs create` | `--persistent-service-id`, `--payload` or `--payload-file` | `--workspace-id`, `--volumes` (UUID, repeatable), `--editor-id` |
| `persistent-services jobs get` | — | `--workspace-id`, `--persistent-service-id`, `--status`, `--limit` (50) |
| `persistent-services jobs status` | `--ps-job-id` | `--workspace-id` |
| `persistent-services jobs cancel` | `--ps-job-id` | — |
| `persistent-services jobs delete` | `--ps-job-id` | — |

Notes:
- Payload contract is the same `{"tool": "<name>", "inputs": {...}}` shape as
  standard service jobs. Paths inside `inputs` that reference volumes MUST use
  the full volume UUID: `/workspace/volumes/<volume_uuid>/...`, and each UUID
  must be passed via `--volumes`.
- Submitting to a **stopped** service is valid: the job queues and the
  platform auto-starts the service. Don't gate submissions on service state.
  A full queue is rejected server-side ("Job queue is full (N/M)").
- Job statuses are an **open vocabulary** (`queued`, `starting`, `running`,
  `success`, `error`, `cancelled`, `timeout`, ...). A job is finished iff
  `completedAt` is set; it failed iff `errorMessage`/`errorCode` is present.
  Treat unknown statuses as still in progress.
- `jobs status` is single-shot and exits 0 for a failed job (the query
  succeeded; the JSON carries the outcome) — poll it in a loop. Its JSON
  output is the job object itself (not a list): check `.completedAt` /
  `.errorMessage` directly. `location` (result zip) and `logfile` are
  presigned URLs (~24 h) regenerated on every query; re-run `jobs status`
  for fresh links. A completed container does not by itself mean the solve
  succeeded — check the log.

## processes — Process discovery index

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `processes get` | — | `--organization-id` (default: `AST_ORGANIZATION_ID`, then the configured org), `--workspace-id` (narrows; not read from env), `--name`, `--process`, `--domain`, `--extension` |

Notes:
- One record per persistent service in the organization: `process`, `domain`,
  `service_name`, `persistent_service_id`, `service_id`, `service_status`,
  `tools` (from the service schema), `volume_name` → `volume_id`,
  `workspace_name` → `workspace_id` (exact-name resolution; `null` plus a
  `volume_resolution`/`workspace_resolution` with candidates when zero or
  several match — never guess, never ask the user for a UUID; the volume is
  looked up in the organization's volumes and in the resolved workspace's,
  then among every volume the caller can list in the organization),
  `extension_hints`, `runtime_class` and `preflight` (always per-tool maps:
  `{"assemble": "minutes", "validate": "minutes"}` — read the entry for the
  tool you are submitting), `results` (per tool: `glob` / `log_glob` / `report_glob` / `manifest` / `log_family`; a flat block in the file applies to every tool), `default_inputs` (keyed by tool). `preflight` is `dry_run` | `self_validating` | `none` (`no_solve` reads as `dry_run`). Field reference: `docs/process-yaml.md`.
- The bindings are authored in `process.yaml` next to `service.yaml`, pointed
  at by a top-level `process:` key (`eclipse_process: 1`, see the README
  "Processes" section). `services deploy` validates it against `service.tools`
  and folds it into the service schema as `process`. A service without it is
  listed with `process: null`; an invalid document with `parse_error`; exit
  code stays 0.
- Read-only and URL-free — the same command runs through the gateway's
  `run_ast(["processes", "get", "--organization-id", "<ORG_ID>"])` on Desktop.

## servers — Server management

**Important:** The CLI uses `--editor-id` (not `--server-id`) due to legacy naming. The UI calls these "servers" but the API still uses "editor" terminology.

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `servers get` | — | `--fields` |
| `servers create` | `--name` | `--workspace-id`, `--instance`, `--storage-size` (`small`=300GB, `medium`=500GB, `large`=1TB) |
| `servers delete` | `--editor-id` | — |
| `servers start` | `--editor-id` | — |
| `servers stop` | `--editor-id` | — |

**Server states:**
- **Running** — active, billable for compute
- **Stopped** — inactive, retains data, storage costs persist
- **Transitioning** — starting or shutting down

**Access methods:**
- **Browser** — `https://<editorId>.tyrell-proxy.studio.eclipse.space/#/workspace`
- **VS Code** — Remote SSH extension (requires SSH keys in Profile settings)
- **Cursor** — Remote SSH (requires SSH keys in Profile settings)
- **Windsurf** — Remote SSH (requires SSH keys in Profile settings)

**Instance types:**
- General Purpose (e.g., t3.xlarge, t3.2xlarge) — standard dev, lightweight tasks
- GPU Accelerated (e.g., g6.xlarge) — ML, rendering, GPU workloads

Use `$CLI services instance-types` to list available options with pricing.

## api-keys — API key management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `api-keys get` | — | `--name` |
| `api-keys create` | `--name`, `--scope` (`user`\|`organization`\|`workspace`) | `--organization-id`, `--workspace-id`, `--expires-at` |
| `api-keys delete` | `--name` | — |

## mcp-servers — MCP server configuration

MCP (Model Context Protocol) Configs connect additional MCP servers to extend agent capabilities with external tools and data sources.

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `mcp-servers get` | `--mode` (`organization`\|`workspace`\|`user`\|`aggregated`) | `--organization-id`, `--workspace-id`, `--tag` (repeatable, all must match), `--category` (repeatable, any may match) |
| `mcp-servers create` | `--scope-type` (`organization`\|`workspace`\|`user`), `--name`, `--config` (JSON) | `--organization-id`, `--workspace-id`, `--description`, `--enabled`, `--tag` (repeatable), `--category <slug>` |
| `mcp-servers edit` | `--mcp-server-id` | `--name`, `--description`, `--config`, `--enabled`, `--tag` (repeatable, replaces all), `--add-tag`, `--remove-tag` (repeatable; not with `--tag`), `--category <slug>`, `--clear-category`, `--organization-id` (acting org for a user-scoped server's labels) |
| `mcp-servers delete` | `--mcp-server-id` | — |
| `mcp-servers overrides` | `--workspace-id` | — |
| `mcp-servers toggle-override` | `--workspace-id`, `--mcp-server-id` | — |

Config example: `'{"command":"npx","args":["@playwright/mcp@latest"]}'`

**Scope behavior:**
- Organization-level: shared across all workspaces, **disabled by default** per workspace (must be explicitly enabled)
- User-level: personal configs, enabled by default
- Workspace-level: scoped to one workspace, enabled by default
- Workspace overrides let you enable/disable inherited configs without modifying originals

## skills — Skill management

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `skills get` | — | `--mode` (`organization`\|`workspace`\|`user`\|`aggregated`; defaults to `--scope-type`, else `aggregated` in a workspace), `--organization-id`, `--workspace-id`, `--scope-type`, `--name` |
| `skills create` | `--scope-type`, `--name`, `--file` (.tar.gz) | `--organization-id`, `--workspace-id`, `--description`, `--version`, `--config`, `--enabled` |
| `skills edit` | `--skill-id` | `--name`, `--description`, `--version`, `--config`, `--enabled`, `--add-tag`, `--remove-tag` (repeatable), `--category <slug>`, `--clear-category`, `--organization-id` (acting org for a user-scoped skill's labels) |
| `skills delete` | `--skill-id` | — |
| `skills replace-package` | `--skill-id`, `--file` | — |
| `skills overrides` | `--workspace-id` | — |
| `skills toggle-override` | `--workspace-id`, `--skill-id` | — |

## tags, categories — Labels

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `tags get` (alias `list`) | — | `--organization-id` (default: `AST_ORGANIZATION_ID`, then the configured org), `--prefix` |
| `categories get` (alias `list`) | — | `--organization-id` (default: `AST_ORGANIZATION_ID`, then the configured org) |

Tags are free-form labels (the server normalizes them); categories are the organization's fixed vocabulary — pass a `slug` from `categories list`. On `edit`, leaving out `--category`/`--clear-category` keeps the current category.

## secrets — Secret management

Secrets are environment variables injected into servers — where API keys and tokens belong instead of a repo or a rules file.

| Command | Required Options | Optional |
|---------|-----------------|----------|
| `secrets get` | — | `--organization-id`, `--workspace-id` |
| `secrets create` | `--name`, a value source, and `--workspace-id` or `--all-workspaces` | `--organization-id` |
| `secrets create` (bulk) | `--env-file`, and `--workspace-id` or `--all-workspaces` | `--organization-id` |
| `secrets edit` | `--secret-id` | value source, `--workspace-id`, `--all-workspaces` |
| `secrets delete` | `--secret-id` | `--yes` |

**Values are write-only.** The platform never returns a secret's value — `secrets get` lists names, scope, and timestamps only. There is no command to read a value back. If a user loses a value, the only remedy is replacing it with `secrets edit`.

**Never put a secret value in `--value` when acting on a user's behalf.** It lands in shell history and the process list. Use one of:

```bash
# Preferred — value on stdin, never touches disk or history
printf '%s' "$VALUE" | ast secrets create --name OPENAI_API_KEY \
  --value-stdin --workspace-id <WORKSPACE_ID>

# For multi-line values such as a PEM private key
ast secrets create --name GITHUB_APP_PRIVATE_KEY \
  --value-file ./key.pem --workspace-id <WORKSPACE_ID>
```

A trailing newline is stripped from `--value-stdin` and `--value-file`.

**Never echo a secret value back to the user, into a file, or into a log.** If you read a value from a file to pass it on, pipe it — do not print it as an intermediate step.

**Exposure is required.** Every secret needs `--workspace-id` (repeatable) or `--all-workspaces`. A secret created with neither cannot afterwards be listed, edited, or deleted, so the CLI rejects it. `--workspace-id` must be a UUID — a typo would otherwise strand the secret the same way.

**Names are scoped per workspace, not per organization.** The same name can exist in two workspaces as two independent secrets; rotating one does not update the other. Point this out before copying a credential into a second workspace.

**Bulk import** with `--env-file` creates one secret per `KEY=VALUE` line. Comments, blank lines, `export ` prefixes, and quoted values are handled. Multi-line values (a PEM spanning lines) are **not** supported and are rejected — create those individually with `--value-file`.

**Deleting** prompts for confirmation in an interactive terminal. When running non-interactively the command proceeds without prompting, so confirm with the user yourself before calling it.

## preauth — Pre-auth enrollment (server-only)

Pre-auth makes a newly created Agent Studio server boot already logged in to `gh`, `claude` and `codex`. It works by holding the user's logins as user-scoped `PREAUTH_*` secrets on the platform and materializing them onto each new server. None of that happens until the user is **enrolled** — until the platform actually holds those secrets, which takes an upload (`seed`) from a server where they are already logged in.

**Enrollment is per name.** There are six names — `PREAUTH_GH_HOSTS_YML_B64`, `PREAUTH_CLAUDE_CREDENTIALS_JSON_B64`, `PREAUTH_CLAUDE_ONBOARDING_JSON_B64`, `PREAUTH_CODEX_AUTH_JSON_B64`, `PREAUTH_GIT_USER_NAME`, `PREAUTH_GIT_USER_EMAIL` — and each is held by the platform, available on this box, or absent. `status` prints `on platform:`, `can be stored from this box:` and `not on this box:`, then the exact `seed --only` line for the difference. `health` is `unenrolled` before any name is stored, `partial` while this box can still contribute names the platform does not hold, and `healthy` once the platform holds everything this box has — **`partial` counts as enrolled**.

| Command | Options | What it does |
|---------|---------|--------------|
| `preauth status` | `--json` | `GET /preauth/status` — per-name view; says **NOT ENROLLED** when the platform holds nothing yet |
| `preauth seed` | `--only`, `--overwrite`, `--json` | `POST /preauth/seed` — the upload; prints names only |
| `preauth push` | `--json` | `POST /preauth/push` — debugging wrapper; the reconcile loop does this every 5 min |
| `preauth materialize` | `--json` | `POST /preauth/materialize` — asynchronous; answers `accepted` and finishes in the background |

**These commands only work from a shell on an Agent Studio server.** They talk to the local anasync API (`http://localhost:8051`, override with `AST_ANASYNC_URL`), not to the platform API — no platform credential, no `~/.ast` access. Anywhere else they fail with `ANASYNC_UNREACHABLE` ("cannot reach anasync API at … — this command must run on the Agent Studio server itself") and print the equivalent `curl`.

**Never run `ast preauth seed` without asking the user first.** Seeding uploads their GitHub and Claude logins to the platform. The design of this feature is that nothing is stored without an explicit, informed "yes" — the editor's enrollment prompt works the same way. The correct agent workflow is:

```bash
# 1. Check, from a shell on the server
ast preauth status --json | jq -r '.enrolment.candidates[]'
```

2. If `candidates` is empty there is nothing to ask about and nothing to seed — stop. Otherwise **ask the user**, in your own words, naming exactly what a yes would store. Build that sentence from the candidate names; the CLI projects names only, so there is no server-written prompt to quote:

| Candidate name | Say |
|---|---|
| `PREAUTH_GH_HOSTS_YML_B64` | your GitHub login |
| `PREAUTH_CLAUDE_CREDENTIALS_JSON_B64`, `PREAUTH_CLAUDE_ONBOARDING_JSON_B64` | your Claude login |
| `PREAUTH_CODEX_AUTH_JSON_B64` | your Codex login |
| `PREAUTH_GIT_USER_NAME`, `PREAUTH_GIT_USER_EMAIL` | your git identity (user.name, user.email) |

e.g. for `PREAUTH_GIT_USER_NAME` + `PREAUTH_GIT_USER_EMAIL`: *"Store your git identity (user.name, user.email) on the platform, so new servers commit as you?"*

3. Only on a yes, seed exactly the names you asked about:

```bash
ast preauth seed --only PREAUTH_GIT_USER_NAME,PREAUTH_GIT_USER_EMAIL
```

**Never widen the consented set.** Seed the names the user was asked about and no others: drop `--only` and you attempt every name, which uploads credentials nobody agreed to. If `enrolment.candidates` is empty there is nothing to ask about and nothing to seed. On an older anasync that sends no `candidates`, ask about GitHub and Claude in as many words and run plain `ast preauth seed`.

`--only` is comma-separated and repeatable, and it changes what a missing input means: with `--only`, a name whose input has vanished since `status` ran is a **skip** and the command exits 0; without it, a missing input is a per-name **error** and the command exits 1, except a missing Codex login, which is skipped (an invalid Codex `auth.json` is still an error). A name outside the known names is rejected locally, before any request leaves the box. `--only` also checks the server first: an anasync that does not advertise `enrolment.candidates` ignores `names` and would seed every name, so the CLI refuses (`does not support per-name seeding`) and sends no upload at all.

**Never echo a credential.** The CLI prints secret *names*, sha256 markers, byte counts and timestamps only — the anasync state file holds no values by contract, and every output path of all four commands is an allow-list, so a new API field is never echoed by accident: the summary prints named fields, and `--json` is a **projection of the known fields** on every one of them — never the response body, in any mode. `status --json` carries the parsed status fields — including `enrolment.{candidates,held,missing}` — plus `enrolled`; `seed --json` carries `status`, `reason`, `selection` (`requested` with `--only`, else `all`), `attempted` and `seeded`/`skipped`/`errors` as `{name, reason?, fix?}` records; `push --json` carries `status`, `reason`, `exit` and `pushed`/`skipped`; `materialize --json` carries `status`, `message`, `operation_id` and `log_file`. A response the CLI cannot parse degrades to the known scalars (for a mutation: `status` and `reason`) plus the top-level key *names*, with `shapeRecognised: false`. Every name list (`enrolment.candidates`/`held`/`missing`, `push.seeded`) passes an identifier guard first — a `PREAUTH_*` name starts with `PREAUTH_`, is `[A-Za-z0-9_]` throughout and is at most 64 characters, and an entry that is not — a token-shaped string included — prints as `(unprintable)`, in both modes and on the fallback path. Do not work around this by reading `~/.config/gh/hosts.yml` or `~/.claude/.credentials.json` yourself.

**Exit codes.** `status` exits 0 whenever the API answered — "not enrolled" is a report, not a failure; script it with `ast preauth status --json | jq .enrolled` (the CLI adds that derived field; it is `null`, with `shapeRecognised: false`, when the CLI could not parse the response). `seed`, `push` and `materialize` exit non-zero on any per-name error, an overall `status: "error"`, a missing status, or a status the CLI does not recognise; the endpoints return HTTP 200 even when they fail, so the body decides — and a result whose success cannot be established is treated as a failure. Per-name errors carry their own fix text and go to stderr — surface them verbatim:

```
  error    PREAUTH_GIT_USER_NAME — git config --global user.name is unset
```

## refresh — Re-sync platform resources (server-only)

`ast refresh` re-syncs what the platform manages on an Agent Studio server — skills, the compiled rules, MCP server configuration and secrets — without sudo and without restarting the editor. It is the manual equivalent of the sync anasync runs at startup and on `entityChanged`. Use it after the user changes a skill, a rule, an MCP server or a secret on the platform and wants it live on this server now.

| Command | Options | What it does |
|---------|---------|--------------|
| `refresh` | — | all four groups, in the fixed order below |
| `refresh --check` | — | report drift, write nothing; **exit 3** when drift is found |
| `refresh --skills` | | re-sync platform skills into `/workspace/skills` |
| `refresh --rules` | | re-sync the compiled agent rules and reference docs |
| `refresh --mcp-servers` | | re-sync MCP server configuration for every editor |
| `refresh --secrets` | | re-sync secrets into `$AST_PATH/.secrets.env` |
| `refresh --all` | | all four groups (the default when no group flag is given) |
| any of the above | `--url <URL>` | base URL of the local anasync API (env `AST_ANASYNC_URL`) |
| any of the above | `--timeout <SECS>` | seconds to wait for **one** group, default 120 |
| any of the above | `--json` | one JSON document instead of the human summary |

**The group order is fixed** whatever order the flags are typed in: `secrets` → `mcp-servers` → `rules` → `skills`. MCP configs resolve `${secrets.NAME}` when they are generated, so stale secrets would be baked into the editor configs; skills runs last because it downloads and extracts zip packages and is the slow one.

**This only works from a shell on an Agent Studio server.** It talks to the local anasync API (`http://localhost:8051`, override with `AST_ANASYNC_URL`), not to the platform API — no platform credential, no `~/.ast` access. Anywhere else it fails with `ANASYNC_UNREACHABLE` ("cannot reach anasync API at … — this command must run on the Agent Studio server itself") and prints the equivalent `curl`.

**Exit codes.** 0 = every selected group succeeded (in check mode: no drift). 1 = anasync unreachable, a group failed, or `--check` is unsupported. **3 = check mode found drift — a report, not a failure**, so it prints no error envelope. Script it:

```bash
ast refresh --check; [ $? -eq 3 ] && echo "something is out of date"
```

**After refreshing secrets, tell the user to open a new shell.** `$AST_PATH/.secrets.env` is sourced at shell startup, so refreshed values are invisible in the current shell and to every agent already running — including you. Do not re-run `ast refresh` expecting the current shell to pick them up; it will not.

**`--check` and per-item detail need anasync-api 0.0.14 or newer** (the CLI gates on the `refresh.check` capability from `/info/version`, not on the version number). On an older server, `--check` is refused before any request is sent (the older API ignores the parameter and would write), and an apply run prints the aggregate message per group instead of per-item outcomes.

`--json` is a projection of the fields this CLI version understands, never the response body. Group keys use the URL spelling, so the MCP key is hyphenated:

```bash
ast refresh --json | jq '.groups["mcp-servers"].summary'
```

## rules — Platform rules

Rules are **markdown documents** that shape how agents work. They're compiled into the agent's context at startup.

**Hierarchy (broadest → most specific, more specific overrides broader):**
Organization → User → Service → Workspace

| Command | Required Options |
|---------|-----------------|
| `rules get-platform` | — |
| `rules get-organization` | `--organization-id` |
| `rules edit-organization` | `--organization-id`, `--rules` \| `--rules-file` |
| `rules get-workspace` | `--workspace-id` |
| `rules edit-workspace` | `--workspace-id`, `--rules` \| `--rules-file` |
| `rules get-service` | `--service-id` |
| `rules edit-service` | `--service-id`, `--rules` \| `--rules-file` |
| `rules get-user` | — |
| `rules edit-user` | `--rules` \| `--rules-file` |

Every `edit-*` takes the markdown from **either** `--rules` or `--rules-file <PATH>` — exactly one, never both. Prefer `--rules-file` for anything longer than a line or two; it avoids shell-quoting a whole document.

```bash
ast rules edit-workspace --workspace-id <WS_ID> --rules-file rules.md
```

The content is sent **literally** — it is not parsed as JSON. Pass raw markdown. **Never** pre-encode it with `jq -Rs .` or `JSON.stringify`; that stores the surrounding quotes and literal `\n` escapes into the rules every agent then receives.

**`edit-*` replaces the entire document — it does not append.** To extend existing rules, read them first, edit, then write the whole thing back:

```bash
ast rules get-workspace --workspace-id <WS_ID> --format table > rules.md
# append or modify rules.md
ast rules edit-workspace --workspace-id <WS_ID> --rules-file rules.md
```

Use `--format table` on `get-*` to print the markdown itself; the default JSON format wraps it in an envelope. Empty rules are rejected, so a write cannot silently blank the document.

## schema — Schema introspection

| Command | Required Options |
|---------|-----------------|
| `schema types` | — |
| `schema fields` | `--type-name <TYPE_NAME>` |
