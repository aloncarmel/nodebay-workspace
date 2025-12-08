# NodeBay Workspace Template

🚀 **This is a GitHub Template Repository** - Users don't clone this directly. Instead, NodeBay creates a copy in their account with their custom configuration.

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                         User Flow                                       │
│                                                                         │
│  1. User visits NodeBay                                                │
│  2. Clicks "Create Workspace"                                          │
│  3. Enters repo URL they want to work on                               │
│  4. NodeBay:                                                           │
│     a. Creates repo from this template in user's account               │
│     b. Pushes nodebay-config.json with user's repo                     │
│     c. Creates codespace on the new repo                               │
│  5. Codespace boots and:                                               │
│     a. Installs all CLIs (Claude, Codex, Gemini, Copilot)             │
│     b. Clones user's repo into /workspaces/dev/{cli}/                  │
│     c. Starts ttyd terminals for each CLI                              │
│     d. Creates ngrok tunnels                                           │
│     e. Announces URLs to NodeBay                                       │
│  6. User sees all 4 CLI terminals in NodeBay dashboard!               │
└────────────────────────────────────────────────────────────────────────┘
```

## 📁 What's Included

```
.devcontainer/
├── devcontainer.json      # Codespace configuration
├── install-tools.sh       # One-time: installs CLIs & system tools
├── boot.sh                # Every start: clones repos, starts terminals
└── workspace-config.json  # Default config (overridden by nodebay-config.json)

nodebay-config.json        # ← Pushed by NodeBay with user's repos
```

## 🤖 Installed CLIs

| CLI | Port | Command |
|-----|------|---------|
| Claude (Anthropic) | 7681 | `claude` |
| Codex (OpenAI) | 7682 | `codex` |
| Gemini (Google) | 7683 | `gemini` |
| Copilot (GitHub) | 7684 | `github-copilot-cli` |

## ⚙️ Configuration

NodeBay pushes a `nodebay-config.json` to the repo root:

```json
{
  "claude": {
    "repo": "https://github.com/user/my-project.git",
    "branch": "main"
  },
  "codex": {
    "repo": "https://github.com/user/my-project.git",
    "branch": "main"
  },
  "gemini": {
    "repo": "https://github.com/user/my-project.git",
    "branch": "main"
  },
  "copilot": {
    "repo": "https://github.com/user/my-project.git",
    "branch": "main"
  }
}
```

Each CLI gets its own copy of the repo in `/workspaces/dev/{cli}/`.

## 🔐 Required Secrets

Set these in Codespace secrets (repo settings or user settings):

| Secret | Required | Description |
|--------|----------|-------------|
| `NGROK_AUTHTOKEN` | ✅ Yes | Ngrok token for tunnels |
| `NODEBAY_API` | ✅ Yes | NodeBay API URL |
| `ANTHROPIC_API_KEY` | For Claude | Claude API key |
| `OPENAI_API_KEY` | For Codex | OpenAI API key |
| `GOOGLE_API_KEY` | For Gemini | Google AI API key |
| `GITHUB_TOKEN` | For Copilot | Auto-provided in Codespaces |

## 🔧 Making This a Template Repo

If you're the maintainer (aloncarmel), enable template:

1. Go to repo Settings
2. Check "Template repository"
3. The repo can now be used with the GitHub "generate" API

## 🖥️ Manual Access

If you need to debug:

```bash
# SSH into codespace
gh codespace ssh -c <codespace-name>

# Check boot logs
cat /tmp/boot.log
cat /tmp/ngrok.log

# Attach to tmux sessions
tmux attach -t claude
tmux attach -t codex
tmux attach -t gemini
tmux attach -t copilot

# Check tunnel status
curl localhost:4040/api/tunnels | jq
```

## 📝 Development

To test changes to this template:

1. Make changes to `.devcontainer/` files
2. Create a test codespace on this repo
3. Check `/tmp/boot.log` for issues
4. Once working, commit and push

---

**Maintained by NodeBay** | [nodebay.vercel.app](https://nodebay.vercel.app)
