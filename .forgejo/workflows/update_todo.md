# update workflow — todo (see update_design.md for detail)

## Phase 1 — implement
- [x] Write update_design.md
- [x] Write update_todo.md
- [x] Add .forgejo/workflows/update.yml

## Phase 2 — verify locally
- [x] YAML parses
- [x] Update loop runs in scratch copy and changes only flake.lock files

## Phase 3 — roll out
- [ ] Commit as `ci:` and push to main
- [ ] Manual workflow_dispatch run produces fix(deps) commit or "no changes"
- [ ] release.yml tags a patch version from that commit
- [ ] build.yml publishes images and -latest symlinks dated today
- [ ] First scheduled monthly run observed in Actions

## Follow-ups
- [ ] Prune old dated artifacts on the server
