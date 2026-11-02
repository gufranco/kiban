<div align="center">

<h1>kiban</h1>

<strong>Run Docker and the local databases a project needs at full speed, on a Mac with a native Colima VM and on Linux with no VM at all.</strong>

English | [日本語](README.ja.md) | [简体中文](README.zh-Hans.md) | [繁體中文 (香港)](README.zh-HK.md)

[![ci](https://img.shields.io/github/actions/workflow/status/gufranco/kiban/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/gufranco/kiban/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/gufranco/kiban?style=flat-square&label=release)](https://github.com/gufranco/kiban/releases/latest)
[![license](https://img.shields.io/github/license/gufranco/kiban?style=flat-square&label=license)](LICENSE)

<p align="center">
  <a href="#quick-start"><strong>Quick start</strong></a> |
  <a href="#settings">Settings</a> |
  <a href="#development">Development</a>
</p>

</div>

One command, six services, and every value overridable from the environment. `kiban` is 基盤, Japanese for foundation.

---

```console
$ kiban status
service    state      address           image
mongo      absent     127.0.0.1:27017   mongo:8
postgres   absent     127.0.0.1:5432    postgres:18-alpine
redis      absent     127.0.0.1:6379    redis:8-alpine
valkey     absent     127.0.0.1:7000    valkey/valkey:8-alpine
redict     absent     127.0.0.1:6380    registry.redict.io/redict:7-alpine
ubuntu     absent     -                 ubuntu:26.04
```

<a id="quick-start"></a>

## Quick start

### Prerequisites

| Tool | Why | Install |
|:-----|:----|:--------|
| POSIX `sh`, `awk`, `sed` | The tool itself | Preinstalled on macOS and Linux. `bash` is not required |
| `docker` | The Docker CLI | `brew install docker`; on Linux, Docker Engine from Docker's apt repository |
| `colima` | The VM on a Mac | `brew install colima` |
| `systemctl`, `sudo` | Starting and stopping the engine on Linux | Preinstalled on Ubuntu |
| `fzf` | Optional: picks containers; kiban falls back to a numbered menu | `brew install fzf`; `apt install fzf` |

### Install

```bash
brew install gufranco/tap/kiban
```

Or from source:

```bash
git clone https://github.com/gufranco/kiban.git
cd kiban
make install
```

`make install` copies the tool, its man page and its bash, zsh and fish completions under `~/.local`, and puts `kiban` in `~/.local/bin`; set `PREFIX` to change that. The Homebrew formula installs the same files.

### Verify

```console
$ kiban doctor
docker             ok       /opt/homebrew/bin/docker
awk                ok       /opt/homebrew/opt/gawk/libexec/gnubin/awk, gnu 5.4.1
sed                ok       /opt/homebrew/opt/gnu-sed/libexec/gnubin/sed, gnu 4.10
colima             ok       /opt/homebrew/bin/colima
rosetta            ok       runs x86_64 images in the VM
fzf                ok       /opt/homebrew/bin/fzf
```

## Usage

| Command | Purpose |
|:--------|:--------|
| `kiban start [profile]` | Start Docker: a Colima VM on a Mac, the engine itself on Linux |
| `kiban stop [profile]` | Stop it |
| `kiban up <service>...` | Create mongo, postgres, redis, valkey, redict or ubuntu the first time, start it after that |
| `kiban down [container]...` | Stop containers, picking from the running ones when none is named |
| `kiban shell [container]`, `kiban logs [container]` | Open a shell in a container, or follow its log |
| `kiban status` | Show every service, its state, its address and its image |
| `kiban reset <service>` | Delete a service's container, volumes and data folder |
| `kiban prune [profile]`, `kiban purge [profile]` | Delete every container, image, volume and build cache; `purge` also deletes the VM |
| `kiban config` | Show every setting and where it came from |
| `kiban` with no arguments | Offer a numbered menu when run in a terminal |
| `kiban doctor`, `kiban version`, `kiban help` | Check the tools, print the version, print the usage page |

`reset`, `prune` and `purge` change nothing until the service or profile name is typed back.

```bash
kiban start                          # the VM, sized from this Mac
kiban up postgres redis              # both, on 127.0.0.1:5432 and :6379
KIBAN_POSTGRES_PORT=5433 kiban up postgres
kiban --cpus 4 --memory 8 start work # a second VM called work
```

kiban follows the shared command-line contract of its family, described in [FAMILY.md](FAMILY.md).

<a id="settings"></a>

## Settings

Every value kiban uses has a default and a `KIBAN_` variable; an option on the command line wins over the variable. `kiban config` lists each one, its value and where it came from:

```console
$ kiban config
setting                  value                                from
KIBAN_PROFILE            default                              default
KIBAN_CPUS               4                                    default
KIBAN_MEMORY             8                                    default
KIBAN_DISK               64                                   default
KIBAN_VM_TYPE            vz                                   default
KIBAN_ARCH               aarch64                              default
KIBAN_ROSETTA            y                                    default
KIBAN_MOUNT_TYPE         virtiofs                             default
KIBAN_MOUNT_INOTIFY      n                                    default
KIBAN_DNS                -                                    default
KIBAN_DATA_DIR           $HOME/Docker               default
```

| Setting | Default |
|:--------|:--------|
| `KIBAN_CPUS`, `KIBAN_MEMORY`, `KIBAN_DISK` | Half the cores between 2 and 4, half the memory between 2 and 8 GiB, a quarter of the disk between 8 and 64 GiB |
| `KIBAN_ARCH`, `KIBAN_ROSETTA` | The machine's own architecture; Rosetta on Apple Silicon |
| `KIBAN_VM_TYPE`, `KIBAN_MOUNT_TYPE`, `KIBAN_MOUNT_INOTIFY` | `vz`, `virtiofs`, `n` |
| `KIBAN_DNS`, `KIBAN_DATA_DIR`, `KIBAN_PROFILE` | The host's resolver, `~/Docker`, `default` |
| `KIBAN_<SERVICE>_IMAGE` | `mongo:8`, `postgres:18-alpine`, `redis:8-alpine`, `valkey/valkey:8-alpine`, `registry.redict.io/redict:7-alpine`, `ubuntu:26.04` |
| `KIBAN_<SERVICE>_PORT` | mongo 27017, postgres 5432, redis 6379, valkey 7000, redict 6380 |
| `KIBAN_MONGO_USER`, `KIBAN_MONGO_PASSWORD`, `KIBAN_POSTGRES_USER`, `KIBAN_POSTGRES_PASSWORD` | `mongo`, `mongo`, `postgres`, `postgres` |
| `KIBAN_POSTGRES_SHM`, `KIBAN_<SERVICE>_MAXMEMORY` | `1g`; `256mb` for redis, valkey and redict |

<a id="speed"></a>

## Speed

| Machine | What kiban does |
|:--------|:----------------|
| Mac, Apple Silicon | A native aarch64 VM on Apple's Virtualization framework with virtiofs, and Rosetta for x86_64 images. It reads the hardware, so a terminal running under Rosetta still gets the native VM |
| Mac, Intel | An x86_64 VM on the same framework, with virtiofs |
| Linux, x86_64 or arm64 | No VM: Docker runs on the machine itself |

Every default image ships amd64 and arm64 builds, so services run without emulation on every machine above. File events stay out of the VM unless `--mount-inotify` asks for them, since forwarding every change in the home folder costs CPU. postgres gets 1 GiB of shared memory instead of Docker's 64 MiB, which limits its parallel queries. kiban itself resolves every setting with no extra process, so `kiban config` answers in about a tenth of a second.

<a id="portability"></a>

## Portability

Everything is POSIX `sh` with ShellCheck `-o all` at zero findings. The suites run on macOS under `/bin/sh` and `dash`, the system's bash 3.2 and zsh, and Homebrew's current bash and zsh, and on Ubuntu under `dash`, `bash`, `bash --posix` and `zsh` in a container. CI repeats them on the family's six toolsets, and `kiban doctor` names the flavor and version of `awk` and `sed`.

<a id="development"></a>

## Development

| Command | Description |
|:--------|:------------|
| `make fmt` | Formats every script with shfmt |
| `make lint` | shfmt, ShellCheck on every script, test and completion, the name check, and mandoc on the man page |
| `make test` | The `bats` tests under the system `sh` |
| `make test-all` | The same tests under every shell, both builds of bash and zsh included on macOS |
| `make test-linux` | The same tests in an Ubuntu container |
| `make coverage` | bashcov line coverage on this Mac and in the Ubuntu container, merged, with the 100% gate CI enforces |

No CI runner can start Colima, so the tests put fake `docker`, `colima`, `systemctl` and host tools on `PATH` and check every call kiban makes. Once CI passes on a push to `main`, semantic-release runs: a `feat` or `fix` commit publishes a release, updates `KIBAN_VERSION` in [`lib/core.sh`](lib/core.sh) and the CHANGELOG, and bumps the Homebrew formula.

## License

[MIT](LICENSE)
