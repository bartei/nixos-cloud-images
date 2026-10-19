# GitHub release pipeline — design

## Goal

Make this repository a public GitHub project that releases itself: on every change to
`main` a version is derived from the commit messages, a tag and a GitHub Release are
created, every image in the repo is built on free GitHub-hosted runners, and the
images are attached to that Release as downloadable assets. Once a month the
`nixpkgs` pins are refreshed so a release with current packages goes out even when
nobody touched the repo. Alongside: a README, a GPL licence and contribution
guidelines so the project reads as a legitimate open-source project.

## Context

Today the repo lives on a private Forgejo (`forge.provvedo.com`) with three
workflows under `.forgejo/workflows/`: `release.yml` (semantic-release → tag),
`build.yml` (tag → build → scp to `cloud-images.opt.provvedo.com`) and the monthly
`update.yml`. GitHub is being added as a second remote. The Forgejo workflows are
left untouched by this work; see "Two forges" below for the conflict that creates.

## Chosen approach: one workflow, four stages

`.github/workflows/release.yml`, jobs chained with `needs:`:

```
[update]  ──>  [release]  ──>  [build × N]  ──gh release upload──>  Release assets
schedule       semantic-       one job per
only           release         image flake
```

1. **update** — runs only on the monthly schedule (or on manual dispatch with the
   `flake_update` input ticked). Runs `nix flake update` in every image flake and, if
   any `flake.lock` changed, commits with `fix(deps): …` and pushes to `main`.
2. **release** — checks out the tip of `main` (so it sees the commit step 1 just
   pushed) and runs the official `python-semantic-release` action with a
   GitHub-specific config file. Outputs `released`, `tag`, and a JSON matrix of all
   `*/nixos-*/flake.nix` directories.
3. **build** — matrix over that JSON, one runner per image, `fail-fast: false`.
   Builds `#image`, names and (where needed) compresses the artifact, writes a
   `.sha256` next to it, and uploads both to the Release with `gh release upload`.

### Why one workflow rather than "release" + "build on tag" like Forgejo

On GitHub, pushes and tags made with the automatic `GITHUB_TOKEN` do **not** trigger
other workflows (GitHub docs: "events triggered by the GITHUB_TOKEN … will not
create a new workflow run", with `workflow_dispatch`/`repository_dispatch` the only
exceptions). The Forgejo setup works around the equivalent rule with a personal
access token. Chaining the jobs inside one workflow needs no PAT at all: the
default token with `contents: write` is enough to commit, tag, create the Release
and upload assets. Fewer secrets, and a workflow that is runnable the moment the
repo is pushed.

The same rule is why the monthly update can be a job in this workflow: its push to
`main` would never trigger a second run, so the release job simply follows it.

## Decisions

### Release tooling: python-semantic-release, via its GitHub action
Keeps the Forgejo and GitHub pipelines on the same tool, the same Conventional
Commits parser, and the same `CHANGELOG.md`. The official action
(`python-semantic-release/python-semantic-release@v10.3.1`, pinned to the version
the Forgejo workflow uses) exposes `released` and `tag` outputs, which drive the
later jobs. Alternatives rejected: `release-please` (different changelog format,
would fork the history of CHANGELOG.md from Forgejo), the JS `semantic-release`
(needs a Node toolchain and plugin config for no gain).

### Separate config file for GitHub
`pyproject.toml` configures the remote as `type = "gitea"` on
`forge.provvedo.com`. The GitHub run uses `.github/semantic-release.toml` through
the action's `config_file` input (`remote.type = "github"`, no asset upload by
PSR). Both files are complete, independent configs; branch rules match. Rejected:
editing `pyproject.toml` in place, which would break the Forgejo release.

The version-bump commit touches only `CHANGELOG.md` (verified on commit
`da9b747`), so `paths-ignore` lists `CHANGELOG.md` and, to match Forgejo,
`pyproject.toml`. This is what stops the bump commit from re-triggering the
workflow — belt and braces, since a `GITHUB_TOKEN` push would not trigger it anyway.

### Asset naming and compression
Assets are named `nixos-<version>-<kind>.<ext>` after the directory layout:

| kind | source output                | asset                           | why                                         |
|------|------------------------------|---------------------------------|---------------------------------------------|
| vm   | `*.qcow2`                    | `nixos-<v>-vm.qcow2`            | built as `qcow2-compressed`; ship as-is so it can be imported by URL |
| ami  | `*.vhd`                      | `nixos-<v>-ami.vhd.zst`         | dynamic VHD, uncompressed; zstd keeps it well under the limit |
| lxc  | `tarball/*.tar.xz`           | `nixos-<v>-lxc.tar.xz`          | already xz                                  |

Each asset gets a `<asset>.sha256`. **GitHub release assets are limited to 2 GiB
per file**; this is the constraint behind compressing the VHD. Measured sizes are
recorded in the verification section. `--clobber` on upload makes re-runs
idempotent.

### Dynamic matrix, not a hard-coded list
The release job emits `{"include":[{"kind":"vm","version":"26.05"},…]}` from the
directories present at the tag. Adding a NixOS release = adding directories; the
workflow never needs editing. (The Forgejo `build.yml` still has a static matrix.)

### Runner setup for image builds
Standard `ubuntu-latest` runners, free for public repos, with three preparatory
steps:

- **KVM.** `make-disk-image.nix` (used by both the qcow2 and the Amazon image) runs
  the installer inside a QEMU VM via `runInLinuxVM`, which declares the `kvm`
  system feature. GitHub's Linux runners expose `/dev/kvm` (hardware-accelerated
  virtualisation has been available on standard Linux runners since 2024), but it
  is `0660 root:kvm` and the Nix build users are not in that group. The udev rule
  from GitHub's own Android-emulator docs sets it to `0666`. The LXC tarball does
  not need a VM.
- **Disk.** The runner's root disk has ~20 GB free; an image build needs the
  closure in the store, the raw disk image under the build dir, the converted
  output, and (for ami) the compressed copy. `wimpysworld/nothing-but-nix@v10`
  (run before Nix is installed) reclaims the preinstalled toolchains and the `/mnt`
  volume into a large `/nix`, and provides `/nix/build` for `build-dir`.
  `witness-carnage: true` makes the purge synchronous so the space exists before
  the build starts (the action's README calls out "VM tests that assemble large
  disk images" as the case needing this). Rejected: `jlumbroso/free-disk-space`,
  which frees less and does not relocate the store.
- **Nix.** `cachix/install-nix-action@v31` with flakes enabled, `build-dir =
  /nix/build` and `system-features` including `kvm`. Rejected:
  `DeterminateSystems/nix-installer-action`, which now defaults to the Determinate
  Nix distribution; upstream Nix is the smaller surprise for contributors.

### Job conditions must carry an explicit status function
First run on GitHub (run 1, 2026-10-18): `release` created `v1.6.2` and the
Release, but every `build` job was *skipped*. Cause: when a job's `if` has no
status-check function, GitHub prepends an implicit `success()`, and the runner
evaluates that as false if **any** job in the transitive `needs` chain was skipped,
not only a direct dependency (actions/runner issue #491). On push events `update`
is skipped by design, `release` survives because its condition starts with
`!cancelled()`, and `build` fell over. Fix: `build` now uses
`!cancelled() && needs.release.result == 'success' && needs.release.outputs.released == 'true'`.
Rule for this workflow: every job downstream of `update` spells out its condition.

### Monthly cadence
Same `0 3 1 * *` as the Forgejo `update.yml`, for the same reason (one image set
per run; keep the pile small). GitHub only runs scheduled workflows from the
default branch and disables them after 60 days without repository activity on a
public repo; the monthly commit itself counts as activity.

### Two forges, one `main` — a conflict to resolve before enabling both
If Forgejo `release.yml` and GitHub `release.yml` both run semantic-release on the
same `main`, each creates its own version-bump commit and tag, and the two `main`
branches diverge. **Exactly one forge must own releases.** This design makes GitHub
self-sufficient and does not touch Forgejo; the recommended follow-up is to make
GitHub the source of truth and either disable the Forgejo `release.yml`/`update.yml`
or turn the Forgejo repo into a pull mirror of GitHub. The Forgejo `build.yml` (scp
to the private image server) can stay if those tags keep arriving via the mirror.
Decision deferred to the owner; tracked in the todo.

### Licence: GPL-3.0-or-later
The request was "GPL"; version 3 is the current GPL, and "or later" is the FSF's
recommended form. Full text in `LICENSE` (verbatim from gnu.org), SPDX identifier
in the README.

### Documentation files
- `README.md` — what the images are, supported versions, how to download and use
  each kind, default access, how to build locally, how releases work, pointers to
  CONTRIBUTING and LICENSE. Badges for release and licence.
- `CONTRIBUTING.md` — issues, PRs, local build/test, the Conventional Commits rule
  (it is load-bearing: it decides whether a release happens and what version it
  gets), how to add a NixOS release, review expectations, conduct.
- Not added, listed as follow-ups: `CODE_OF_CONDUCT.md`, `SECURITY.md`, issue/PR
  templates (the rest of GitHub's community-profile checklist).

## Files touched

- `.github/workflows/release.yml` — new.
- `.github/semantic-release.toml` — new.
- `README.md`, `LICENSE`, `CONTRIBUTING.md` — new.
- `.github/github_design.md`, `.github/github_todo.md` — these docs.

Nothing under `.forgejo/`, `pyproject.toml` or the flakes changes.

## Deploy and blast radius

Deploy = push `main` to the GitHub remote. That first push triggers `release.yml`;
whether it releases depends on whether the commits since the last `v*` tag contain
`feat`/`fix` (the tags must be pushed too, `git push github --tags`, or
semantic-release will start from 0.0.0 and release everything as 1.0.0). The commit
adding these files should be typed `ci:`/`docs:` so it is not itself a release.

Blast radius: GitHub only. Each release runs 7 image builds (≈15–30 min each,
parallel) and attaches ≈7 assets plus checksums. No effect on the Forgejo pipeline
or the private image server, apart from the divergence risk described above.

Secrets: none. `GITHUB_TOKEN` with `permissions: contents: write`.

## Verification

1. `release.yml` passes yamllint; the matrix-generation shell snippet produces the
   expected JSON when run locally against the repo tree.
2. `semantic-release -c .github/semantic-release.toml --noop version --print` loads
   the config and computes the expected next version from the local history.
3. Local builds of the three 26.05 images: outputs exist where the workflow looks
   for them; asset sizes (after compression where applicable) are below 2 GiB.
   Measured 2026-10-18 (nixos-26.05, packaging step run verbatim):

   | asset                      | size      | note                                    |
   |----------------------------|-----------|-----------------------------------------|
   | `nixos-26.05-vm.qcow2`     | 719 MB    | shipped as-is                           |
   | `nixos-26.05-ami.vhd.zst`  | 744 MB    | raw VHD is **3.41 GB**, over the limit   |
   | `nixos-26.05-lxc.tar.xz`   | 243 MB    | shipped as-is                           |

   `zstd -T0 -15` on the VHD took ~65 s wall / 8.7 min CPU here; expect a few
   minutes on a 4-core runner. Compressing the VHD is therefore mandatory, not
   an optimisation.
4. After the first push to GitHub: workflow runs, `release` job creates tag and
   Release, every `build` job uploads its asset and checksum, Release page lists
   `nixos-<v>-{vm.qcow2,ami.vhd.zst,lxc.tar.xz}` + `.sha256` for every version.
5. Manual dispatch with `flake_update` ticked exercises the monthly path end to end.
6. Download one qcow2 from the Release and boot it in QEMU; check cloud-init runs.
