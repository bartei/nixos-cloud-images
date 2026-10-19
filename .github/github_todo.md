# GitHub release pipeline — todo (see github_design.md for detail)

## Phase 1 — pipeline
- [x] Write github_design.md
- [x] Write github_todo.md
- [x] Add .github/semantic-release.toml
- [x] Add .github/workflows/release.yml

## Phase 2 — project documents
- [x] Add LICENSE (GPL-3.0-or-later)
- [x] Add README.md
- [x] Add CONTRIBUTING.md

## Phase 3 — verify locally
- [x] release.yml passes yamllint
- [x] Matrix snippet emits expected JSON
- [x] semantic-release loads the GitHub config in noop mode
- [x] Local 26.05 builds: outputs found, asset sizes below 2 GiB

## Phase 4 — roll out
- [ ] Decide which forge owns releases; disable the other's release/update workflows
- [x] Push main and tags to the GitHub remote
- [ ] First run: tag, Release and all assets present
- [ ] Manual dispatch with flake_update exercises the monthly path
- [ ] Boot a downloaded qcow2 in QEMU

## Follow-ups
- [ ] CODE_OF_CONDUCT.md, SECURITY.md, issue and PR templates
- [ ] Decide whether the Forgejo build.yml keeps publishing to the private server
