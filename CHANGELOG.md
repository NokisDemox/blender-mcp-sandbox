# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Isolated, GPU-accelerated, rootless container dev environment for
  Blender `5.2.2` (NVIDIA CDI, Wayland + X11), with the Blender MCP
  add-on `1.0.3` served on `localhost:10800`.
- Repository layout: `docker/` build context (`Dockerfile`,
  `startup_init.py`, `entrypoint.sh`); `./workspace` host folder mounted
  as in-container `/workspace` (the only writable host mount).
- `docker/startup_init.py`: idempotent Blender prefs bootstrap (online
  access, MCP add-on enabled on `:10800` with autostart, Cycles CUDA with
  visible GPU devices enabled, render output in workspace), baked into the
  image at build and re-applied at every container start via
  `docker/entrypoint.sh`, which also prints a GPU audit before launching
  Blender.
- MCP bridge server (`blender-mcp`) installed in the image from the pinned
  `MCP_VERSION` tag (`1.0.3`; pip + venv, no uv), reaching the add-on via
  `BLENDER_MCP_HOST`/`BLENDER_MCP_PORT` container env.
- OpenCode installed in the image, wired to the bridge via
  `workspace/opencode.json` (`/usr/local/bin/blender-mcp`).
- `Makefile` lifecycle: `up` / `down` / `rebuild` / `ps` / `shell` /
  `purge` / `audit` / `help`, Podman-first with Docker fallback,
  `BLENDER_VERSION` and `MCP_VERSION` forwarded through compose build
  args and `make up`/`rebuild`.

[unreleased]: https://github.com/NokisDemox/blender-mcp-sandbox/compare/main...dev
