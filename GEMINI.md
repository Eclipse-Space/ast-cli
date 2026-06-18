# Eclipse Agent Studio CLI (ast)

A CLI for authenticating and working with the Eclipse Agent Studio platform.

## Binary

The CLI binary is `ast`. Resolve it in this order:

```bash
command -v ast                     # already on PATH
$HOME/.local/bin/ast               # default install location
```

If neither exists, install it:

```bash
curl -fsSL https://raw.githubusercontent.com/Eclipse-Space/ast-cli/main/install.sh | bash
```

## Key Commands

```bash
ast auth login      # Log in via browser (OAuth2 PKCE relay)
ast auth register   # Create a new account
ast auth whoami     # Show current authenticated user
ast auth logout     # Clear stored credentials
ast workspaces get  # List workspaces
```

## Environment Variables

```bash
AST_MANAGER_URL   # Required for auth login/register
AST_DECKARD_URL   # Required for auth register only
AST_API_KEY       # Alternative to interactive login
AST_BEARER_TOKEN  # Highest-priority auth override
```

The CLI loads `.env` automatically from the working directory via dotenvy.

## Auth Flow

Both `auth login` and `auth register` use a two-phase relay pattern designed for
agents (no localhost callback required). See the `ast` skill for the full
step-by-step agent workflow.
