# kiban

Guidance for anyone, human or agent, changing kiban. What kiban is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything kiban shares with the rest of the kodougu family, and it is the same in every member. This file holds only what is exclusive to kiban, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into `FAMILY.md` instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`bin/kiban`](bin/kiban) | The entry point: usage, options, their checks, the menu and the command dispatch |
| [`lib/`](lib) | The modules. [`lib/state.sh`](lib/state.sh) declares every global, [`lib/settings.sh`](lib/settings.sh) resolves each setting and sizes the VM, [`lib/engine.sh`](lib/engine.sh) runs the VM or the engine, [`lib/services.sh`](lib/services.sh) runs the services and the picker |
| [`man/kiban.1`](man/kiban.1) | The man page |
| [`completions/`](completions) | bash, zsh and fish completions |
| [`test/`](test) | The `bats` suite, its helpers with the fake tools, the fake `sudo` and the Linux container script |
| [`scripts/`](scripts) | Coverage, the coverage gate, the Linux coverage run and the name check, which `make` runs |
| [`.github/scripts/`](.github/scripts) | The toolset helper and the release version stamp, which only CI and the release run |

## Names

- Globals carry `KB_`; function-scoped variables carry a per-function `kb_` prefix. Resolved settings live in `KB_S_<SETTING>`.
- Settings come from `KIBAN_<SETTING>`; test switches are `KIBAN_OS`, `KIBAN_TERMINAL`, `KIBAN_INTERACTIVE`, `KIBAN_TEST_SHELLS` and `KIBAN_TEST_RECORD`.
- Output goes through `kb_info`, `kb_say`, `kb_success`, `kb_error` and `kb_warning`.

## Behaviour

- kiban has several jobs, so a bare `kiban` on a terminal offers the numbered menu.
- Every setting resolves option, then `KIBAN_<SETTING>`, then default, and `kiban config` prints each with where it came from.
- `--json` applies to `status` and `config`.

## Domain rules

- Speed comes first: kiban is fast enough to call in a loop. Settings resolve into globals with no subshell, the OS and the Docker context are read once, and host facts are read only by the commands that size a VM. `kiban config` went from 0.41 to 0.90 s down to 0.07 to 0.11 s on an Apple Silicon Mac (measured 2026-11-01); `status` is bound by the Docker CLI call.
- The VM architecture comes from the hardware, `sysctl -n hw.optional.arm64`, never from `uname -m`, which reports `x86_64` in a terminal running under Rosetta and would start a fully emulated VM.
- On Linux there is no VM: `start` and `stop` drive `systemctl`, and every Docker call uses the default context.
- The macOS caps are the owner's choice (2026-11-01): half the cores between 2 and 4, half the memory between 2 and 8 GiB, a quarter of the disk between 8 and 64 GiB.
- Every planned image tag ships amd64 and arm64 builds, so services run natively on Apple Silicon and Linux arm64 (checked 2026-11-01 with `docker manifest inspect`).
- postgres keeps its data in the `postgres-store` volume mounted at `/var/lib/postgresql`, which works for postgres 18 and earlier; the old module's `postgres-data` volume is left untouched for recovery.
- redict listens on 6380, since redis holds 6379; valkey keeps 7000.
- Colima cannot run in CI, so the tests drive fake `docker`, `colima`, `systemctl`, `fzf`, `sysctl`, `nproc`, `uname`, `df` and `arch` on `PATH`, and `KIBAN_OS` lets every macOS and Linux branch run on either system.

## Release

- `KIBAN_VERSION` lives in [`lib/core.sh`](lib/core.sh).

## Gaps against FAMILY.md

- Not yet published: no GitHub repository, no formula in the tap, and kiban is not yet in the member table of `FAMILY.md` (as of 2026-11-01).
- The tests drive fakes in place of Docker and Colima, which no CI runner can start, rather than the real tools.
