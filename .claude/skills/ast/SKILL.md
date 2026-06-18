---
name: ast
description: Use when an agent needs to authenticate or register with the ast CLI (Eclipse Agent Studio) via OAuth. Covers both auth login and auth register — both use the same two-phase relay pattern.
argument-hint: [optional: "login" or "register", plus environment name like "local", "dev", "test", "prod"]
---

# CLI OAuth — Login & Register

Both commands use the management server's PKCE relay and are designed for agents
(no localhost callback required). Both follow the **same two-phase pattern**:

- **Phase 1** (`auth login` or `auth register`) — exits immediately, prints labeled tokens
- **Phase 2** (`auth callback`) — run in the background, blocks on SSE until browser flow completes
- **Phase 2 alternative** (`auth status`) — non-blocking single check, for clients that cannot run background processes

| Command | When to use |
|---------|-------------|
| `auth login` | User already has an account |
| `auth register` | User needs to create a new account |

## Prerequisites

- The CLI ships with prod defaults built-in (API, auth, manager, and Deckard URLs) — no env vars needed for standard usage
- To target a different environment, set `AST_ENVIRONMENT` to `dev`, `test`, or `local`, or override individual URLs via env vars
- The management server must be running and reachable

## Resolving the CLI Binary

Before running any command, determine which binary to use. Try each option in order:

```bash
# 1. Already installed on PATH
if command -v ast >/dev/null 2>&1; then
    CLI="ast"

# 2. Pre-built release binary present locally
elif [ -f /workspace/repos/agent-studio-cli/target/release/ast ]; then
    CLI="/workspace/repos/agent-studio-cli/target/release/ast"

# 3. Try online install (downloads pre-built binary from GitHub Releases)
elif curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install.sh | bash; then
    CLI="ast"

# 4. Offline fallback — build from source (requires cargo)
elif command -v cargo >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/cargo" ]; then
    CARGO="${HOME}/.cargo/bin/cargo"
    command -v cargo >/dev/null 2>&1 && CARGO="cargo"
    cd /workspace/repos/agent-studio-cli
    $CARGO build --release 2>&1
    CLI="/workspace/repos/agent-studio-cli/target/release/ast"

else
    echo "ERROR: Cannot install ast. Install cargo (https://rustup.rs) or ensure internet access." >&2
    exit 1
fi

echo "Using CLI: $CLI"
```

Use `$CLI` in place of `ast` in all commands below.

## Quick Check

The CLI has prod defaults built-in — no `.env` file or env vars are required for standard usage.
To override defaults (e.g., for a different environment), you can export env vars or use a `.env` file:

```bash
# Verify current config (prod defaults used if no overrides set)
$CLI auth whoami 2>&1
```

---

# Two-Phase Flow (applies to both login and register)

Both `auth login` and `auth register` follow this same pattern:

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

# auth login — Existing Account Login

## Phase 1: Initiate Login

Run synchronously (not in background) — it exits immediately:

```bash
cd /workspace/repos/agent-studio-cli
$CLI auth login 2>&1
```

### Expected Output

```
[AUTH_URL] https://keycloak.example.com/realms/eclipse/protocol/openid-connect/auth?client_id=...
[INSTANCE_ID] xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[WAIT_TOKEN] yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
[ACTION] Start `auth callback --instance-id xxx --wait-token yyy` in the background, then present AUTH_URL to the user...
```

## Phase 2: Complete Login (Callback)

Start this **immediately after Phase 1, in the background** — before presenting the URL to the user:

```bash
cd /workspace/repos/agent-studio-cli
$CLI auth callback \
  --instance-id <INSTANCE_ID_FROM_PHASE_1> \
  --wait-token <WAIT_TOKEN_FROM_PHASE_1> \
  2>&1
```

Use `run_in_background: true` (Bash tool) so the agent continues while the callback waits on SSE.

## Phase 2 Alternative: Non-blocking Status Check

If your client **cannot run background processes**, use `auth status` instead of `auth callback`. It makes a single GET request and returns immediately:

```bash
cd /workspace/repos/agent-studio-cli
$CLI auth status \
  --instance-id <INSTANCE_ID_FROM_PHASE_1> \
  --wait-token <WAIT_TOKEN_FROM_PHASE_1> \
  2>&1
```

- `[AUTH_COMPLETE]` — tokens stored, user is authenticated (exit code 0)
- `[AUTH_WAITING]` — user hasn't completed browser flow yet (exit code non-zero)
- `[AUTH_FAILED]` — error occurred (exit code non-zero)

Call `auth status` on your own schedule — retry until you get `[AUTH_COMPLETE]` or `[AUTH_FAILED]`.

## Agent Flow

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

# auth register — New Account Registration

## Phase 1: Initiate Registration

Run synchronously (not in background) — it exits immediately:

```bash
cd /workspace/repos/agent-studio-cli
$CLI auth register 2>&1
```

### Expected Output

```
[REGISTER_URL] https://deckard.example.com/register-as/?source=cli&instanceId=xxx&loginUrl=<encoded>
[INSTANCE_ID] xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[WAIT_TOKEN] yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
[ACTION] Start `auth callback --instance-id xxx --wait-token yyy` in the background, then present REGISTER_URL to the user...
```

## Phase 2: Complete Registration (Callback or Status)

**The same `auth callback` (or `auth status`) command is used as for login.** Start it immediately in the background:

```bash
cd /workspace/repos/agent-studio-cli
$CLI auth callback \
  --instance-id <INSTANCE_ID_FROM_PHASE_1> \
  --wait-token <WAIT_TOKEN_FROM_PHASE_1> \
  2>&1
```

## Agent Flow

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

# Expected Callback Output (for both login and register)

```
[AUTH_USER] c w (user@example.com) | MyOrg
[AUTH_COMPLETE] Tokens stored. You are authenticated.
```

If the output is unavailable when notified (file cleaned up), fall back to:
```bash
$CLI auth whoami 2>&1
```

---

# Presenting to the User

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

# Error Cases

| Output | Meaning |
|--------|---------|
| `AST_MANAGER_URL is not set` | Should not occur with prod defaults — if seen, set `AST_ENVIRONMENT=prod` or export the URL manually |
| `AST_DECKARD_URL is not set` | Should not occur with prod defaults — if seen, set `AST_ENVIRONMENT=prod` or export the URL manually (register only) |
| `Manager relay returned error` | Management server rejected the request — check server logs |
| `Invalid wait token — access denied` | Wrong wait_token. Re-run Phase 1. |
| `Session expired or not found` | Took too long. Re-run Phase 1. |
| `Timed out waiting for authentication` | User didn't complete browser flow within 15 min. |
| `Auth failed: Token exchange with Keycloak failed` | Server-side PKCE exchange failed — check Keycloak config |

---

# Common Commands

```bash
# Check current auth status
$CLI auth whoami 2>&1

# Log out
$CLI auth logout 2>&1
```

## Troubleshooting

### "Keycloak OAuth is not configured on this server"
The management server is missing `KEYCLOAK_ISSUER` or `KEYCLOAK_CLI_REDIRECT_URI` env vars.
Check the management server's environment configuration.

### "Manager relay request failed: connection refused"
The management server isn't running or `AST_MANAGER_URL` points to the wrong host.
Check with: `curl -s $AST_MANAGER_URL/health`

### Callback URL not registered in Keycloak
If the browser shows "Invalid redirect_uri" after login, the manager's callback URL
(`$TYRELL_MANAGER_PUBLIC_URL/oauth/keycloak/callback`) needs to be added to the
Keycloak `deckard` client's "Valid redirect URIs" list.

### Fallback: Direct PKCE Flow (login only)
If the manager relay is unavailable, clear the manager URL to use the
direct paste-URL flow instead:
```bash
export AST_MANAGER_URL=""
$CLI auth login 2>&1
```

### Architecture (same for both login and register)

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
