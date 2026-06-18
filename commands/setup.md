---
description: Set up the Eclipse Agent Studio CLI — checks authentication, guides login or registration, and gets the user into a running server.
---

# Setup — Eclipse Agent Studio CLI

Follow these steps in order. **The goal is to get the user a running server URL as fast as possible.**

## Step 0: Resolve the CLI Binary

Before running any command, determine which binary to use. Try each option in order:

```bash
if command -v ast >/dev/null 2>&1; then
    CLI="ast"
elif [ -f /workspace/repos/agent-studio-cli/target/release/ast ]; then
    CLI="/workspace/repos/agent-studio-cli/target/release/ast"
elif [ -f "$HOME/.local/bin/ast" ]; then
    CLI="$HOME/.local/bin/ast"
else
    echo "CLI_NOT_FOUND"
fi
echo "CLI=$CLI"
```

If `CLI_NOT_FOUND`, tell the user the CLI binary is not installed and offer to install it:
```bash
curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install.sh | bash
```
After install, re-resolve the binary. If install fails, stop and report the error.

## Step 1: Check Authentication Status

Run this synchronously:

```bash
$CLI auth whoami 2>&1
```

**If the output contains a user identity** (e.g., a name and email) — the user is already logged in.
Skip to **Step 3**.

**If the output indicates the user is not authenticated** (e.g., `AUTH_REQUIRED`, error, or no user info) — continue to Step 2.

## Step 2: Log In or Register

**STOP and ask the user:**

> Do you already have a Eclipse account, or do you need to create one?

Wait for their response. Do NOT proceed until they answer.

- **If they have an account** → invoke the `ast` skill with "login":
  Use the ast skill to run the full two-phase login flow (`auth login` → `auth callback` in background → present URL → wait for completion).

- **If they need to sign up** → invoke the `ast` skill with "register":
  Use the ast skill to run the full two-phase registration flow (`auth register` → `auth callback` in background → present URL → wait for completion).

After authentication completes successfully, continue to Step 3.

## Step 3: Confirm Organization

Greet the user (use their name from `auth whoami` if available), then:

1. Run `$CLI organizations get --format table`
2. If the user belongs to **multiple organizations**, list them and ask which one to use
3. Switch if needed with `$CLI organizations use --organization-id <ORG_ID>`

**Do not skip this step.** If you default to the wrong org, everything downstream is wrong.

**Important:** Once the organization is confirmed, use `--organization-id <ORG_ID>` on all subsequent commands to scope results to that org. Without it, queries return resources across ALL organizations the user belongs to.

## Step 4: Find or Create a Workspace

1. Run `$CLI workspaces get --organization-id <ORG_ID> --format table`
2. If the user **has workspaces**, ask which one they want to use (or if they want a new one)
3. If the user **has no workspaces**, offer two paths:
   - **"Explore an example"** — point them to the examples marketplace: `https://studio.eclipse.space/<organizationId>/examples/workspaces/`
   - **"Start fresh"** — create a new workspace (ask for a name and brief description)

## Step 5: Deliver the Server URL

This is the goal of the entire setup flow.

1. Run `$CLI servers get --format table`
2. Find the server associated with the workspace (a server auto-starts when a workspace is created)
3. If the server is **running**, construct the URL: `https://<editorId>.tyrell-proxy.studio.eclipse.space/#/workspace`
4. If the server is **stopped**, start it with `$CLI servers start --editor-id <EDITOR_ID>`, then construct the URL

Present the URL to the user:

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
