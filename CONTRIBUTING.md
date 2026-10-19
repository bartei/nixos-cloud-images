# Contributing

Thanks for taking the time to contribute. This document explains how the project
works and what makes a change easy to review and release.

## Ways to contribute

- **Report a bug** — open an issue with the image name and version (for example
  `nixos-26.05-vm`), the release tag you downloaded, the platform you ran it on, and
  what you observed versus what you expected. Console or cloud-init logs help a lot.
- **Request a feature** — open an issue describing the use case before writing code
  for anything non-trivial, so we can agree on the approach first.
- **Submit a change** — fork, branch, commit, open a pull request. Small, focused
  pull requests are reviewed faster than large ones.
- **Add a NixOS version or target** — see the dedicated section below.

## Development setup

You need [Nix](https://nixos.org/download/) with flakes enabled. Building the
`vm` and `ami` images also needs a working `/dev/kvm`, because the disk image is
assembled inside a QEMU virtual machine; the `lxc` tarball builds without it.

```sh
git clone https://github.com/bartei/nixos-cloud-images
cd nixos-cloud-images
nix build ./vm/nixos-26.05#image -L
```

Every image is a self-contained flake in `<kind>/nixos-<version>/` with its own
`configuration.nix`, `flake.nix` and `flake.lock`. There is deliberately no shared
top-level flake: a change to one version cannot affect another, and each lock
file can move independently.

### Testing a change

Build the image you changed, then boot it:

- **vm**: `qemu-system-x86_64 -enable-kvm -m 2048 -nographic -drive file=result/nixos.qcow2,if=virtio,snapshot=on`
  and confirm it reaches a login prompt and that cloud-init runs (with a NoCloud
  seed if your change touches networking or users).
- **lxc**: create a container from the tarball on a Proxmox host and confirm
  networking and SSH key injection work.
- **ami**: boot the `.vhd` locally with QEMU as a smoke test (`-drive file=...,format=vpc`);
  a full EC2 import is only needed for changes to the Amazon-specific modules.

Say in the pull request what you tested and how.

## Commit messages — this matters

Releases are fully automated with
[python-semantic-release](https://python-semantic-release.readthedocs.io/), which
reads the commit messages on `main` to decide **whether** to release and **which
version** to cut. Commits therefore follow
[Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Effect on the next release |
|--------|----------------------------|
| `fix:` | patch release (`1.6.1` → `1.6.2`) |
| `feat:` | minor release (`1.6.1` → `1.7.0`) |
| `feat!:` / footer `BREAKING CHANGE:` | major release |
| `docs:`, `ci:`, `chore:`, `refactor:`, `test:`, `style:` | no release |

Guidelines:

- Use the imperative mood and keep the subject under about 70 characters:
  `feat(vm): enable serial console on ttyS0`.
- Scope with the image kind when the change is specific to one:
  `fix(ami): …`, `feat(lxc): …`.
- A change that only touches images is user-visible, so it is a `fix` or a `feat`,
  not a `chore`. A `chore` commit on `main` produces no release and the change
  would not reach users until the next monthly rebuild.
- Explain *why* in the body when the diff does not make it obvious.

Pull requests are squash-merged; the pull request title becomes the commit
subject, so give the title the same care.

## Pull request checklist

- [ ] The change builds for every version it touches (`nix build ./<kind>/nixos-<v>#image`).
- [ ] The resulting image boots and the changed behaviour was tested as described above.
- [ ] `flake.lock` files are only changed when the change requires it; routine
      `nixpkgs` bumps are done by the monthly pipeline, not by hand.
- [ ] Commit messages / pull request title follow Conventional Commits.
- [ ] Documentation (`README.md`, this file) is updated if behaviour visible to
      users changed.

## Adding a NixOS version

1. Copy the previous version's directory for each kind you want to provide:
   `cp -r vm/nixos-25.11 vm/nixos-26.05` (likewise `ami/`, `lxc/`).
2. In each new `flake.nix`, point `nixpkgs.url` at the new `nixos-<version>`
   branch and update `version` where it appears (the lxc flake embeds it in the
   tarball name).
3. Update `system.stateVersion` in `configuration.nix` where it is set.
4. Delete the copied `flake.lock` and run `nix flake update` inside the directory
   to lock the new branch.
5. Build and boot each image.
6. Add the version to the support table in `README.md`.
7. Commit as `feat: add nixos-<version> images`.

The GitHub pipeline discovers image directories automatically, so no workflow
changes are needed.

## Adding a new target

Open an issue first. A new kind means a new top-level directory (`<kind>/nixos-<version>/`),
a build output named `image`, and a packaging case in
`.github/workflows/release.yml` that knows where the output lands and what the
asset should be called. Keep the configuration minimal: these are base images,
and users customise them after boot.

## Review and merge

- A maintainer reviews every pull request. Expect questions about the *why*; they
  are not a rejection.
- CI must be green. Image builds take a while; be patient with the runners.
- Maintainers may push small fixes to your branch (typos, rebases) to get a change
  over the line; we will tell you when we do.

## Conduct

Be kind and assume good faith. Disagreements are about the code, not the people.
Harassment or disrespectful behaviour of any kind is not welcome here; maintainers
will remove comments, commits or contributors that cross that line.

## Licence

By contributing you agree that your contributions are licensed under the project's
licence, the GNU General Public License v3.0 or later (see [LICENSE](LICENSE)).
