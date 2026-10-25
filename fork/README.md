# Genex — personal fork

This is a fork of [genex-games/genex-desktop](https://github.com/genex-games/genex-desktop) (MIT) with
local patches and features on top of an official release. Everything fork-specific lives in `fork/`;
the patches themselves are ordinary commits on `main`, listed in [PATCHES.md](PATCHES.md).

| | |
|---|---|
| Base release | the tag in [`BASE`](BASE) |
| Branch | `main` = base tag + fork commits (rebased, never merged, so each patch stays one readable commit) |
| Remotes | `upstream` = genex-games/genex-desktop; `origin` = your own fork, once you create one |
| Installed at | `~/.local/lib/genex` (launcher `~/.local/bin/genex`); app data stays in `~/.config/Genex` |
| Platform | Linux x64 only (the install script uses the official Linux zip) |

## Daily use

```sh
fork/scripts/check.sh               # typecheck + the tests covering the patches (~1 min)
fork/scripts/install.sh --restart   # build, install over ~/.local/lib/genex, restart Genex
```

`install.sh` builds the app code with `scripts/build.mjs --release` and puts it into the **official
release of the same version** (downloaded once to `~/.cache/genex-fork/`, checked against the release's
`SHA256SUMS`). Electron, its libraries and `node_modules` are the official ones; only `app.asar`'s
`dist/` is rebuilt. An unpatched release build reproduces the official `dist/` byte for byte (checked
on v0.1.23, apart from a timestamp in `dist/resources/vendor/VERSION.json`), so the installed app
differs from the official one only by the fork's commits.

Each install keeps the previous copy as `~/.local/lib/genex.bak-<time>`. To go back:

```sh
pkill -f '^/home/dotexec/.local/lib/genex/genex'
rm -rf ~/.local/lib/genex && mv ~/.local/lib/genex.bak-<time> ~/.local/lib/genex
```

The installed build says what it is in `dist/FORK.json` inside `app.asar`
(`{"base", "commit", "dirty", "built"}`).

## Adding a patch or feature

1. Commit on `main` — one commit per patch, message starting `fork:` and saying why.
2. Add it to [PATCHES.md](PATCHES.md): what, why, files, and the test that covers it.
3. Add its test file to `fork/scripts/check.sh` if it is not already covered.
4. `fork/scripts/check.sh && fork/scripts/install.sh --restart`.

Keep patches small and in the upstream style (read `AGENTS.md` — comments explain *why*, the
`check:static` rules apply). A patch that would help everyone is worth offering upstream as a PR;
once upstream has it, drop the fork commit at the next sync.

## Moving to a new Genex release

```sh
fork/scripts/sync-upstream.sh          # newest release tag; or name one: sync-upstream.sh v0.1.24
fork/scripts/check.sh
fork/scripts/install.sh --restart
```

`sync-upstream.sh` tags the current fork as `fork-before-<tag>`, rebases the fork's commits from the old
base onto the new tag, and updates `BASE`. On a conflict, fix it and `git rebase --continue`, then commit
`fork/BASE` with the new tag yourself. To abandon: `git rebase --abort`, or later
`git reset --hard fork-before-<tag>`.

## Things that undo the fork

- **Genex's own updater or the apt package** installs the official build over `~/.local/lib/genex`.
  After an official update, run `sync-upstream.sh` + `install.sh` again.
- **Harness patches** (`src/harness-seed/`) reach an existing install only for files you never edited:
  Genex copies the seed into `~/.config/Genex/workspaces/harness/` and keeps any file you changed
  there (`src/substrate/seed-upgrade.ts`). Edit the live copy too when it has diverged.

## Related local setup (not in this repo)

- OpenCode provider for the LAN model server: `~/.config/opencode/opencode.json` (`tensorfold`,
  `http://192.168.0.224:8888/v1`). Needs the fork's LAN-HTTP patch to be reachable from Genex's sandbox.
- The Local AI Studio plugin: `~/Workspace/local-ai/genex-plugin/local-ai-jobs`.
