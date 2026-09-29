# blender-mcp-sandbox

Isolated, GPU-accelerated, rootless container dev environment for
**Blender 5.2.2** with the **Blender MCP add-on 1.0.3** and **OpenCode
inside the container**.

All Blender work stays inside `./project_data` (mounted as `/workspace`).
The host is never given writable mounts outside the display sockets.

## Architecture

```text
Host (KDE Plasma 6 / KWin, NVIDIA GPU, rootless Podman)
 |
 |-- ${XDG_RUNTIME_DIR} (ro, Wayland) ──┐
 |-- /tmp/.X11-unix (ro, X11 fallback) ─┤
 |-- ./project_data ──> /workspace (rw) ┤
 |                                       v
 |                          Container: blender-mcp
 |                           - ubuntu:24.04 + Blender 5.2.2 tarball
 |                           - Blender MCP add-on 1.0.3 (:10800)
 |                           - OpenCode (TUI, runs inside container)
 |                           - NVIDIA CDI (nvidia.com/gpu=all)
```

Data flow: you edit files in `./project_data` on the host, run Blender
and OpenCode inside the container via `make shell`, and automate Blender
through MCP on `localhost:10800`.

## Prerequisites

- Linux with rootless Podman (Docker works as fallback) and `podman-compose`
  (or `docker compose`).
- NVIDIA GPU with CDI configured (`nvidia.com/gpu=all` must resolve).
- **Nvidia container toolkit** installed.
- Wayland session (primary) and/or X11 socket at `/tmp/.X11-unix`.
- On Wayland hosts, `make up` runs `xhost +local:` for X11 fallback; safe
  to ignore if you are Wayland-only.

## Quickstart

```bash
make help            # list targets and variables
make up              # first launch: create + start containers + run GPU audit
make stop            # stop containers, keep them for restart
make start           # restart stopped containers without recreating
make audit           # print Blender version, GPU vendor/renderer
make shell           # open bash inside the running container
make ps              # show container status
make down            # stop AND REMOVE containers (next start needs up)
```

Override per run, e.g.:

```bash
make up DISPLAY_SERVER=x11 BLENDER_VERSION=5.2.2
```

> Note: `DISPLAY_SERVER` is currently accepted but does not yet switch

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `PROJECT_NAME` | `blender_mcp_sandbox` | Compose project / container name |
| `BLENDER_VERSION` | `5.2.2` | Blender tarball version (forwarded to build) |
| `MCP_VERSION` | `1.0.3` | MCP add-on version (Dockerfile `ARG`; compose passthrough planned) |
| `DISPLAY_SERVER` | `wayland` | Intended display protocol (switching not yet implemented) |
| `WORKSPACE_DIR` | `./project_data` | Host workspace mounted at `/workspace` |
| `BLENDER_MCP_HOST` | `localhost` | Host the bridge uses to reach the add-on (compose env) |
| `BLENDER_MCP_PORT` | `10800` | Port the bridge uses to reach the add-on (compose env) |

Blender is preconfigured by `startup_init.py`: Allow Online Access on,
MCP add-on enabled on `localhost:10800` with autostart, Cycles on CUDA
with visible GPU devices enabled. The script runs once at image build
and again at every container start (`entrypoint.sh`), because GPU
devices can only be enumerated when the NVIDIA device is attached.
`userpref.blend` lives inside the image (`/root/.config/...`), so it
survives `down/up`; to change a preset, edit `startup_init.py` and
`make rebuild`. Do not hand-edit prefs inside a running container --
entrypoint will overwrite them on next start.

Key files:

- `Dockerfile` — single-stage `ubuntu:24.04` image: Blender tarball,
  MCP extension install, `startup_init.py` bake, MCP bridge (pip/venv),
  OpenCode install, `entrypoint.sh` startup.
- `startup_init.py` — idempotent Blender prefs bootstrap (see above).
- `entrypoint.sh` — re-applies prefs with GPU present, prints GPU audit,
  launches Blender GUI.
- `docker-compose.yml` — CDI GPU, Wayland+X11 mounts, `10800:10800`,
  `./project_data:/workspace`.
- `Makefile` — `up / start / stop / down / rebuild / ps / shell / purge / audit / help`.
- `TODO.md` — source of truth for status. Read before contributing.
- `AGENTS.md` — agent operating manual and locked decisions.

## Verification

```bash
make audit
```

Expected: `GPU Vendor: NVIDIA Corporation` (or similar) and a CUDA/OptiX
renderer string. `llvmpipe` / `softpipe` means acceleration failed —
do not proceed; check CDI and display sockets.

MCP (`:10800`) and OpenCode wiring are **not yet verified** — tracked as
`TODO.md` Milestone 4. The add-on is installed at build time but not
confirmed to auto-enable on boot.

## Limitations (MVP)

- NVIDIA only. No AMD, no software-render acceptance path.
- `DISPLAY_SERVER` toggle and compose overrides not implemented yet.
- Image is single-stage and unoptimized (>4 GB likely); slimming planned.
- OpenCode install script is unpinned (`curl | bash`); pinning planned.
- Conversations must survive `down/up` — mechanism not yet implemented.
- Procedural welding tooling (`welding_generator.blend`) is deferred.

## License

MIT — see `LICENSE`.
