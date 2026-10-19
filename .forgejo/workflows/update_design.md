# update workflow — design

## Goal

Once a month, refresh the `nixpkgs` pin (`flake.lock`) of every NixOS image flake in
this repository, then rebuild and re-publish the affected images, with no manual
step.

## Context: the existing pipeline

The repo already has a two-stage release chain in `.forgejo/workflows/`:

1. `release.yml` — on push to `main` (except version-bump commits) runs
   `python-semantic-release`, which bumps `pyproject.toml`/`CHANGELOG.md`, commits,
   and pushes a `vX.Y.Z` tag using the `REGISTRY_TOKEN` personal access token.
2. `build.yml` — on a `v*` tag, builds `vm/`, `ami/` and `lxc/` images for each
   version in the matrix on the `native` runner and uploads them over SSH to
   `cloud-images.opt.provvedo.com`, updating the `-latest` symlinks.

A tag pushed with a PAT (not the automatic actions token) does trigger `build.yml`;
this is stated in `release.yml` and is relied on today.

## Chosen approach

Add a third workflow, `update.yml`, that runs monthly on a cron schedule (and on
`workflow_dispatch` for manual runs) and does only one thing: run
`nix flake update` in every flake directory and, if any `flake.lock` changed, commit
the result to `main` with a Conventional Commits `fix(deps): …` message and push.

Everything downstream is the existing chain, unchanged:

```
update.yml  --push to main-->  release.yml  --push tag-->  build.yml  --scp-->  server
(monthly cron)                 (patch bump)                (build + upload)
```

### Why this shape

- **Reuses build and upload logic verbatim.** The build matrix, SSH setup and
  publish steps live in one place; the scheduled path cannot drift from the tag path.
- **Lock files in git match what is deployed.** Every published image corresponds
  to a committed `flake.lock` and a tagged version, exactly like a manual release.
- **Visible history.** Each monthly update is a commit and a CHANGELOG entry, so a
  regression can be bisected to a specific nixpkgs bump.

## Decisions

### Commit type is `fix`, not `chore`
`pyproject.toml` has no `commit_parser` configuration, so python-semantic-release
uses its default conventional parser, in which `chore` does **not** bump the
version. A `chore` commit would be pushed, `release.yml` would run, and nothing
would be tagged, so nothing would be built. `fix(deps)` produces a patch release
and therefore a tag. `feat` was rejected as semantically wrong for a dependency
bump. Configuring the parser to treat `chore(deps)` as a patch was rejected as
extra config for no gain.

### Run on the `native` runner, not `ubuntu-latest`
`nix flake update` needs Nix. The `native` runner already has Nix with flakes
enabled (it is what `build.yml` uses). `ubuntu-latest` is a `node:20-bookworm`
container and would need Nix installed on every run. Rejected: slower, and a second
Nix setup to maintain.

Consequences inherited from `build.yml`: `$HOME` is unset on the native runner, so
git identity is set with repo-local `git config` rather than `--global`.

### Push with `REGISTRY_TOKEN` via `actions/checkout`
`actions/checkout@v4` with `token: ${{ secrets.REGISTRY_TOKEN }}` persists the
credential in the checkout's git config, so a plain `git push` works and the push
is made with the PAT. This matters: a push made with the automatic actions token
would not trigger `release.yml`. The same token and reason are already documented
in `release.yml`.

### Update every flake found, do not hard-code the list
The workflow loops over `vm/*/ ami/*/ lxc/*/` and updates any directory containing
`flake.nix`. Adding a new image version therefore needs no change to this workflow
(the `build.yml` matrix still has to be extended, as today).

`nix flake update` is run as `cd "$dir" && nix flake update` (no path argument)
because the positional/`--flake` form changed between Nix versions and the runner's
Nix version is not pinned.

### No build before committing
The update job does not build images itself. Building all seven flakes would double
the monthly build time, and the existing `build.yml` run *is* the verification: a
broken nixpkgs bump fails that job for the affected version, which is visible in
Forgejo Actions, and the upload step is never reached, so the `-latest` symlink on
the server keeps pointing at the last good image. The next monthly run retries with
a newer nixpkgs. `fail-fast: false` on the build matrix means one broken version
does not block the others.

### No-op when nothing changed
If `git status --porcelain` is empty after updating, the job exits 0 without
committing. Branches that have stopped moving (e.g. an end-of-life NixOS release)
simply produce no change.

### Update loop tolerates a failing flake
`nix flake update` on an end-of-life release exits 0 with no change (nixpkgs keeps
every release branch), so no version is skipped. A flake that does fail is
reported with a warning and the loop moves on, so one broken input cannot block
the monthly update for the others.

### Schedule: monthly, not weekly
`0 3 1 * *` — the 1st of every month, 03:00 UTC. Weekly was the first choice but
was rejected because every run that finds a change produces a full new image set
on the server (qcow2 + vhd + lxc tarball per version) and nothing prunes old ones;
monthly keeps that growth to roughly one set per month. Forgejo runs scheduled
workflows only from the default branch, which is `main`.

## Files touched

- `.forgejo/workflows/update.yml` — new workflow (this design).
- `.forgejo/workflows/update_design.md`, `.forgejo/workflows/update_todo.md` — docs.
  Forgejo only loads `*.yml`/`*.yaml` from the workflows directory, so Markdown
  files here are inert.

No change to `build.yml`, `release.yml`, `pyproject.toml` or any flake.

## Deploy and blast radius

Deploy is a normal commit to `main`. That commit itself goes through
`release.yml`; it should be typed `ci:` so it is **not** released (ci commits do
not bump the version under the default parser).

Blast radius once live: on the 1st of every month, a patch release and a full rebuild/upload of
all images. Server-side, each run adds one dated artifact per image under
`/data/cloud-images`, `/data/ami` and `/data/lxc-templates`; nothing is deleted, so
disk usage grows by roughly one image set per month. Pruning old dated artifacts is
out of scope here and tracked as a follow-up in the todo.

Secrets used: `REGISTRY_TOKEN` (already exists for `release.yml`). No new secrets.

## Verification

1. YAML parses (`yamllint` / `python -c 'import yaml; ...'`).
2. Locally, in a scratch copy of the repo, run the same loop the workflow runs and
   confirm it touches only `flake.lock` files and produces a clean diff.
3. After merging, trigger `update` manually via `workflow_dispatch` in Forgejo
   Actions and confirm:
   a. a `fix(deps): …` commit lands on `main` (or the job logs "no changes");
   b. `release.yml` runs on that commit and pushes a new `vX.Y.Z` tag;
   c. `build.yml` runs on the tag and the `-latest` symlinks on the server point at
      files dated today.
4. On the next 1st of the month, confirm the scheduled run appears in Actions.
