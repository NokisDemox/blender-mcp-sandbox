"""Blender first-boot / every-boot configuration (idempotent).

Run headless: ``blender --background --python /opt/startup_init.py``.

What it configures (all guarded, safe to re-run):
  1. System -> Allow Online Access (required by the MCP add-on autostart).
  2. Enables the ``blender_mcp_addon`` extension (installed at image build).
  3. MCP add-on prefs: host ``localhost``, port ``10800`` (matches
     ``docker-compose.yml`` mapping and ``BLENDER_MCP_PORT``), autostart on.
  4. Cycles: compute device ``CUDA``; enables every CUDA/OPTIX device found.
     On machines without a visible GPU the device list is empty and this
     step is a no-op (CPU fallback) -- NOT a failure.
  5. Workspace defaults: render output -> ``/workspace/renders`` (created
     if missing). Note: Blender has no "default open folder" preference;
     Open/Save dialogs start in the process working directory, which
     ``entrypoint.sh`` pins to ``/workspace`` via ``cd``.
  6. Saves ``userpref.blend`` so everything persists for the GUI session.

Exit code is 1 when a critical step fails, so image builds break loudly.
"""

import os

import bpy

WORKSPACE_DIR = "/workspace"
RENDER_OUTPUT_DIR = os.path.join(WORKSPACE_DIR, "renders")

MCP_ADDON_MODULES = (
    # Extension repository id (Blender 4.2+ extension system).
    "bl_ext.user_default.mcp",
    # Legacy module name, kept as a fallback.
    "blender_mcp_addon",
)
MCP_HOST = "localhost"
MCP_PORT = 10800

_failures = []


def _ok(msg):
    print("[startup_init] OK: " + msg)


def _fail(msg):
    print("[startup_init] FAIL: " + msg)
    _failures.append(msg)


def _configure_online_access():
    system = bpy.context.preferences.system
    if not hasattr(system, "use_online_access"):
        _fail("preferences.system has no use_online_access attribute")
        return
    system.use_online_access = True
    _ok("online access enabled (bpy.app.online_access applies on next launch)")


def _find_mcp_addon():
    """Return the registered id of the MCP add-on, or None."""
    addons = bpy.context.preferences.addons
    for candidate in MCP_ADDON_MODULES:
        if candidate in addons:
            return candidate
    return None


def _enable_mcp_addon():
    found = _find_mcp_addon()
    if found is not None:
        _ok("MCP add-on already enabled as '%s'" % found)
        return found
    last_error = None
    for candidate in MCP_ADDON_MODULES:
        try:
            bpy.ops.preferences.addon_enable(module=candidate)
        except Exception as ex:  # noqa: BLE001 - try next candidate
            last_error = ex
            continue
        found = _find_mcp_addon()
        if found is not None:
            _ok("MCP add-on enabled as '%s'" % found)
            return found
    _fail("could not enable MCP add-on (tried %s): %r" % (MCP_ADDON_MODULES, last_error))
    return None


def _configure_mcp_prefs():
    found = _find_mcp_addon()
    if found is None:
        _fail("cannot set MCP prefs, add-on not enabled")
        return
    addon_prefs = bpy.context.preferences.addons[found].preferences
    try:
        addon_prefs.host = MCP_HOST
        addon_prefs.port = MCP_PORT
        addon_prefs.use_autostart = True
    except Exception as ex:  # noqa: BLE001 - report and fail loudly
        _fail("setting MCP prefs raised %r" % (ex,))
        return
    _ok(
        "MCP prefs host=%s port=%d autostart=%s"
        % (addon_prefs.host, addon_prefs.port, addon_prefs.use_autostart)
    )


def _configure_cycles_cuda():
    cycles = bpy.context.preferences.addons.get("cycles")
    if cycles is None:
        _fail("cycles add-on not found in preferences")
        return
    cprefs = cycles.preferences
    try:
        cprefs.compute_device_type = "CUDA"
    except Exception as ex:  # noqa: BLE001 - report and fail loudly
        _fail("setting compute_device_type=CUDA raised %r" % (ex,))
        return
    _ok("cycles compute device type = %s" % cprefs.compute_device_type)
    try:
        if hasattr(cprefs, "refresh_devices"):
            cprefs.refresh_devices()
        enabled = 0
        for device in list(cprefs.devices):
            if device.type in {"CUDA", "OPTIX"}:
                device.use = True
                enabled += 1
                print("[startup_init] GPU device enabled: %s (%s)" % (device.name, device.type))
        if enabled:
            _ok("%d CUDA/OPTIX device(s) enabled" % enabled)
        else:
            print("[startup_init] NOTE: no CUDA/OPTIX devices visible, CPU fallback kept")
    except Exception as ex:  # noqa: BLE001 - report and fail loudly
        _fail("enabling GPU devices raised %r" % (ex,))


def _configure_workspace():
    try:
        os.makedirs(RENDER_OUTPUT_DIR, exist_ok=True)
    except Exception as ex:  # noqa: BLE001 - report and fail loudly
        _fail("creating %s raised %r" % (RENDER_OUTPUT_DIR, ex))
        return
    filepaths = bpy.context.preferences.filepaths
    if not hasattr(filepaths, "render_output_directory"):
        _fail("preferences.filepaths has no render_output_directory attribute")
        return
    filepaths.render_output_directory = RENDER_OUTPUT_DIR
    _ok("render output directory = %s" % RENDER_OUTPUT_DIR)


def _save_userpref():
    try:
        bpy.ops.wm.save_userpref()
    except Exception as ex:  # noqa: BLE001 - report and fail loudly
        _fail("save_userpref raised %r" % (ex,))
        return
    _ok("userpref saved")


_configure_online_access()
_enable_mcp_addon()
_configure_mcp_prefs()
_configure_cycles_cuda()
_configure_workspace()
_save_userpref()

if _failures:
    print("[startup_init] %d FAILURE(S)" % len(_failures))
    raise SystemExit(1)
print("[startup_init] all good")
