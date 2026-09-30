# AI sandbox script

Runs an AI coding CLI (Claude, Copilot, ...) inside an isolated
[microsandbox](https://github.com/superradcompany/microsandbox), mirrors your
current repo into it, and captures whatever the sandbox produces as a new commit
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
ai <branch> [--profile copilot|claude] [--stacks dotnet,node,dart,rust,python,docker]
```

- `<branch>` - name of the branch/worktree created under `/tmp/claude/<repo-name>-<branch>` to
  hold whatever the sandbox session changes.
- `--profile` - which CLI to launch inside the sandbox (default: `copilot`).
- `--ref` - optional reference branch to start off of (default: `master`).
- `--stacks` - comma-separated language/framework stacks to enable (or set `MSB_STACKS`).
  For each stack, mounts its host package cache into the sandbox and opens network egress
  to its package registry. Choices: `dotnet`, `node`, `dart`, `rust`, `python`, `docker`
  (`docker` starts `dockerd` in the sandbox and allows Docker Hub egress).
- `--context` - pass an additional git repository as a context/reference which
  will be mounted read-only into the sandbox
- `--no-memory` - disable the persistent cross-project agent memory mount (see below)

On exit:

- if the sandbox working directory is dirty, commits the leftover changes there as
  `WIP: <profile> sandbox session (<branch>)`
- transplants every commit made in the sandbox since it started (individually, history intact)
  onto the new worktree/branch via `git format-patch` / `git am`
- removes the worktree and branch again if nothing changed

## Configuration

Set via environment variables on the host before running `ai`:

- `MSB_CLAUDE_TOKEN` / `MSB_COPILOT_TOKEN` - auth token for the selected profile, injected into
  the sandbox as a secret (`CLAUDE_CODE_OAUTH_TOKEN` / `GITHUB_TOKEN`). Required.
- `MSB_IMAGE` - override the sandbox image (default: `msb-base:latest`).
- `MSB_EXTRA_DOMAINS` - comma-separated list of extra domains to allow through the sandbox's
  network egress policy, on top of the profile's defaults.
- `MSB_DOCKER_IMAGES` - comma-separated host docker images (e.g. `postgres:16,redis:7`) to
  preload into the sandbox's docker (requires the `docker` stack). Images must already be
  pulled on the host; exports are cached in `~/.msb/docker-images/`.
- `MSB_STACKS` - comma-separated stacks, alternative to `--stacks`. Both are merged together.

Each profile also mirrors selected host config into the sandbox if present (e.g.
`~/.claude/CLAUDE.md`, `~/.claude/skills`, `~/.claude/agents` for the `claude` profile;
`~/.copilot/instructions` for `copilot`).

If the repo you're running `ai` in has a repo-root `CLAUDE.md` that's untracked
(e.g. deliberately gitignored, kept local-only), it's mirrored into the sandbox too -
otherwise only committed files reach the sandbox.

Your host git identity (`user.name`/`user.email`) is copied into the sandbox automatically.

## Agent memory

Each profile gets a persistent, cross-project memory file, bind-mounted
read-write into every sandbox session at `/home/msb/.ai-memory/MEMORY.md`,
backed by `~/.msb/memory/<profile>/MEMORY.md` on the host. It survives across
sandboxes and across repos - unlike everything else in the sandbox, it isn't
torn down when the session ends.

At session start, the agent is told (via `claude`'s `--append-system-prompt`,
or `copilot`'s `-i` first-turn prompt) to read that file and to append a
short bullet whenever the user gives it a durable, project-independent
instruction (a preference, a correction, a habit to carry into unrelated
future projects). Repo- or task-specific detail doesn't belong there.

Disable this with `--no-memory` for a given run.
