# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Toolchain

- Assume Go 1.26 features are available in this repo. Do not preserve compatibility with older Go versions.
- The module is `github.com/nezhahq/agent`.
- The runtime default config path is `config.yml` next to the compiled binary (`cmd/agent/main.go`).

## Common commands

- Build the agent binary:
  - `go build -o nezha-agent ./cmd/agent`
- Show CLI help:
  - `go run ./cmd/agent --help`
- Run the agent directly with a config file:
  - `go run ./cmd/agent -c /absolute/path/to/config.yml`
- Run all tests in a stable way:
  - `CI=1 go test ./...`
- Run tests for one package:
  - `go test ./pkg/util`
- Run a single test:
  - `go test ./pkg/util -run TestGenerateQueue`
- Run the standard static check used in this repo:
  - `go vet ./...`

Notes:
- There is no Makefile, Taskfile, or golangci-lint config in this repository.
- `pkg/utls/roundtripper_test.go` makes a live HTTPS request unless `CI` is set, so plain `go test ./...` can fail depending on network behavior.

## High-level architecture

### Process model

`cmd/agent/main.go` is the center of the application. It combines:
- CLI parsing (`agent`, `edit`, `service`)
- config loading and validation
- OS service integration through `github.com/nezhahq/service`
- the long-running reconnect loop for the Nezha server

The main runtime flow is:
1. `preRun()` initializes DNS/HTTP behavior, loads `AgentConfig`, and passes config into the monitor package.
2. `run()` dials the Nezha server over gRPC.
3. After connecting, the agent sends a host snapshot with `ReportSystemInfo2`.
4. It then keeps two bidi streams alive:
   - `RequestTask` for server-driven tasks
   - `ReportSystemState` for periodic state reporting
5. On any stream/connection failure, it cancels workers, waits, and reconnects.

### Config flow

`model/config.go` defines `AgentConfig` and is the single source of truth for persisted agent settings.

Important behavior:
- Config is loaded from YAML and then overridden by `NZ_` environment variables via koanf.
- A UUID is generated and saved automatically if one is missing.
- `Save()` writes the config back to disk with restrictive permissions.
- `ValidateConfig()` enforces required connection settings and normalizes reporting intervals.

If you add a config field, check all of these places together:
- `model/config.go`
- `cmd/agent/commands/edit.go`
- the consuming code in `cmd/agent/main.go` or `pkg/monitor/*`

These are not automatically kept in sync.

### Monitoring pipeline

The monitoring logic is split out of the main loop into `pkg/monitor/*`.

Key ideas:
- `GetHost()` returns mostly static machine inventory (platform, CPU, memory total, disk total, arch, boot time, version).
- `GetState()` returns periodic metrics (CPU, memory/swap usage, disk usage, load, process count, connection counts, temperatures, network counters/speeds).
- The package keeps shared cached state such as boot time, network transfer totals, computed speeds, and temperature snapshots.
- Disk and NIC collection are filtered through allowlists from config.
- Public IP/GeoIP inputs are refreshed through `pkg/monitor/myip.go` using explicit IPv4/IPv6 HTTP clients from `pkg/util/http.go`.

### Transport and networking behavior

`setEnv()` in `cmd/agent/main.go` changes global networking behavior before the agent starts working:
- it replaces the default Go DNS resolver with one that prefers configured DNS servers or the built-in public fallback list
- it installs a uTLS-backed HTTP transport for outbound HTTPS requests so the agent presents a browser-like TLS fingerprint

Related pieces:
- `model/auth.go` injects `client_secret` and `client_uuid` as per-RPC metadata for gRPC calls. `RequireTransportSecurity()` returns the agent's TLS config value.
- `pkg/util/http.go` provides single-stack HTTP clients used when the agent must force IPv4 or IPv6 resolution.
- `pkg/utls/roundtripper.go` contains the browser-fingerprint transport implementation.

### Concurrency model

Shared mutable state in `cmd/agent/main.go` uses atomic types:
- `initialized`, `hostStatus`, `ipStatus`, `reloadStatus` are `sync/atomic.Bool` -- use `.Load()` to read, `.Store()` to write.
- `doWithTimeout` uses a buffered channel + `select` for timeout enforcement. It does not cancel the underlying goroutine on timeout (goroutine completes in the background).

The `monitor` package (`pkg/monitor/monitor.go`) uses `atomic.Bool` (`updateTempStatus`) and `sync.Mutex` (`stateLock`) for its cached state.

### Protocol boundary

`proto/nezha.proto` defines the server contract. The generated files in `proto/*.pb.go` are derived from it and should not be hand-edited.

Most client-side use of that contract happens in `cmd/agent/main.go`, which is the best place to inspect when changing server interaction behavior.

### Task handling status

Be careful not to assume every declared task type is live.

- `model/task.go` declares many task constants.
- The current `doTask()` implementation in `cmd/agent/main.go` only handles keepalive.
- `pkg/fm/tasks.go` contains a separate file-manager stream implementation for `IOStream`, but that path is not part of the main task switch in `doTask()`.

When changing task behavior, verify the full path from protobuf definition to stream wiring to handler invocation.

### Release/build configuration

Release automation is split across:
- `.github/workflows/cross-compile.yaml`
- `.goreleaser.yaml`

Current release behavior:
- GitHub Actions triggers on published releases.
- GoReleaser builds Linux amd64 artifacts only.
- Release builds set `GOEXPERIMENT=jsonv2` and `CGO_ENABLED=0`.
- Version and architecture are injected via ldflags into `pkg/monitor.Version` and `main.arch`.

If you change release targets or embedded version metadata, update both files together.

## Repository-specific notes

- The README is minimal; the code is the authoritative source for runtime behavior.
- The interactive `edit` command currently covers NIC allowlists, disk allowlists, DNS, UUID, temperature, and debug settings. If behavior around config editing seems inconsistent, compare `cmd/agent/commands/edit.go` with `model/config.go` before changing anything.
