# AI sandbox script

Runs an AI coding CLI (Claude, Copilot, ...) inside an isolated [microsandbox](https://github.com/microsandbox/microsandbox),
mirrors your current repo into it, and captures whatever the sandbox produces as a new commit
on a fresh git worktree/branch on the host.

## Prerequisites

- Build the base sandbox image before first use:

```sh
docker build -t msb-base:latest .
```

- Import the docker image into microsandbox:

```sh
docker save msb-base:latest | msb load
```

## Usage

```sh
ai <branch> [--profile copilot|claude]
```

- `<branch>` - name of the branch/worktree created under `/tmp/claude/<repo-name>-<branch>` to
  hold whatever the sandbox session changes.
- `--profile` - which CLI to launch inside the sandbox (default: `copilot`).
- `--ref` - optional reference branch to start off of (default: `master`).

On exit:

- diffs the sandbox working directory against its checkout
- applies that diff as a single commit (`WIP: <profile> sandbox session (<branch>)`) onto the
  new worktree/branch
- removes the worktree and branch again if nothing changed

## Configuration

Set via environment variables on the host before running `ai`:

- `MSB_CLAUDE_TOKEN` / `MSB_COPILOT_TOKEN` - auth token for the selected profile, injected into
  the sandbox as a secret (`CLAUDE_CODE_OAUTH_TOKEN` / `GITHUB_TOKEN`). Required.
- `MSB_IMAGE` - override the sandbox image (default: `msb-base:latest`).
- `MSB_EXTRA_DOMAINS` - comma-separated list of extra domains to allow through the sandbox's
  network egress policy, on top of the profile's defaults.

Each profile also mirrors selected host config into the sandbox if present (e.g.
`~/.claude/CLAUDE.md`, `~/.claude/skills`, `~/.claude/agents` for the `claude` profile;
`~/.copilot/instructions` for `copilot`).

Your host git identity (`user.name`/`user.email`) is copied into the sandbox automatically.
