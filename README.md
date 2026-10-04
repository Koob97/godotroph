# Godotroph

This repository is a fork of the Godot engine by autotroph games, for use developing Haunted Heist.
The main branch is `4.7-HauntedHeist`. 

# Dependencies

## GodotSteam

Current version: `4.20.1`. Built for compatibiltiy with Godot 4.7.1 and Steamworks 1.64.

[GodotSteam](https://godotsteam.com/) is a C++ module used to bridge the gap between Godot, and the Steamworks SDK. The `4.7-HauntedHeist` branch has the [source code](https://codeberg.org/godotsteam/godotsteam/releases/tag/v4.20.1) for GodotSteam copied into the `/modules` directory. When compiling the editor, debug, and release templates this ensures that GodotSteam is a core module of the engine. It gives global access to the `Steam` object for accessing functionality. There is technically an option to include GodotSteam as a GDExtension in the `/addons` directory of your Godot project, but including it as a core module of the engine is a bit more robust (more efficient, more reliable, no godotsteam.dll required in exported project content)

## Steamworks SDK

Current version: `1.64`. Matches the version of GodotSteam we are using.

The [Steamworks SDK](https://partner.steamgames.com/downloads/list) is Valve's official C++ library for accessing Steam features (networking, achievements, lobbies, cloud saves, overlay, etc.). GodotSteam is only a wrapper around it, so the SDK is also required to compile the engine. The SDK can be downloaded from the Steamworks website, but has already been added to this project in `modules/godotsteam/sdk`. The `public` and `redistributable_bin` folders are the relevant ones.

Note the SDK also contains `steam_api64.dll` which is the runtime library required for the game executable to run. This file must be placed as a sibling of the `.exe` and uploaded in the content bundle to Steam.


# Compiling godotroph

## Setup

In order to compile godotroph, one must first install a few pre-requisites:
* [Scoop](https://scoop.sh/). This is similar to Homebrew, but for Windows. Automatically adds itself to PATH.
* sCons (installed with `scoop install scons`). This is the build system needed for compiling source code into executables. It __orchestrates__ the build, but needs VS to function as the actual compiler. If Python is not installed, note that this step will install Python as it is a dependency of sCons.
* [Visual Studio 2022 Community](https://gist.github.com/Chenx221/6f4ed72cd785d80edb0bc50c9921daf7). Make sure C++ tools are installed.
* sentry-cli (installed with `scoop install sentry-cli`)

Then, from the repo root, install the Direct3D 12 and AccessKit (screen reader) build dependencies:
```
python misc/scripts/install_d3d12_sdk_windows.py
python misc/scripts/install_accesskit.py
```
These download prebuilt libraries into `%LOCALAPPDATA%\Godot\build_deps`, where SCons finds them automatically. This only needs to be done once per machine.

## Building

To build everything in one step, run `./build.ps1` from the repo root. It runs both builds below, moves the resulting `.exe`/`.pdb` files (plus the D3D12 runtime DLLs they need) into a dated subfolder like `bin/2026-07-22`, then uploads that folder's `.pdb` files to Sentry. SCons itself hardcodes `/bin` as its output directory, so this post-build move is the supported way to organize results. `sentry-cli` must already be logged in (`sentry-cli login`).

To build the editor:
```
scons platform=windows target=editor debug_symbols=yes -j12
```

__The most important thing to note here is that DEBUG SYMBOLS are enabled.__ Enabling debug_symbols produces a `.pdb` file which is needed for translating memory dumps (e.g. crash dumps either from Windows or from Sentry) into readable stacktraces of actual C++ function calls. Without this, memory dumps are not readable.

To build the release template:
```
scons platform=windows target=template_release debug_symbols=yes lto=full optimize=speed
```

Parameters of note:
- `lto=full` enables link-time optimization. Builds take longer, but execution has maximum efficiency.
- `optimize=speed` maximizes runtime performance

Direct3D 12 (DirectX) and screen reader (AccessKit) support are enabled by default; they require the install scripts from the Setup section to have been run. To skip them instead, add `d3d12=no accesskit=no`.


## Profiling with Tracy

[Tracy](https://github.com/wolfpld/tracy) is a tracing profiler used to inspect CPU timelines in the C++ engine (and instrumented GDScript zones). Follows the [Godot 4.6 Tracy docs](https://docs.godotengine.org/en/4.6/engine_details/development/profiling/tracy.html). For editor-only issues, profile the **editor**; for player-like performance, profile a **release template**.

### One-time setup

Current version: `0.13.0` (must match between the Tracy source used at compile time and the Tracy server binary).

From the repo root, clone the Tracy source into `thirdparty/tracy` (gitignored, same idea as Perfetto):

```
git clone -b v0.13.0 --single-branch https://github.com/wolfpld/tracy.git thirdparty/tracy
```

On Windows, download the matching pre-built server from the [Tracy v0.13.0 release](https://github.com/wolfpld/tracy/releases/tag/v0.13.0) (`windows-0.13.0.zip`) and extract it. On this machine that lives at `Documents/Godot/tracy-profiler/`, which contains `tracy-profiler.exe`.

### Build a Tracy-enabled editor

From the repo root:

```
scons platform=windows target=editor debug_symbols=yes profiler=tracy profiler_path=thirdparty/tracy -j12
```

### Build a Tracy-enabled release template

From the repo root:

```
scons platform=windows target=template_release debug_symbols=yes lto=full optimize=speed profiler=tracy profiler_path=thirdparty/tracy
```

Notes:
* `debug_symbols=yes` is required so Tracy's sampling / stack features can resolve symbols (same reason we keep `.pdb`s for Sentry).
* `profiler_path` must point at the Tracy clone (the directory that contains `public/TracyClient.cpp`).
* By default Godot builds with `profiler_record_on_demand=yes` (`TRACY_ON_DEMAND`), so the game only records while the Tracy server is connected. That avoids unbounded RAM use if you forget to connect.
* Do **not** ship Tracy-enabled binaries to players; build a normal release template (no `profiler=...`) for production/Steam uploads.

### Record a trace

1. Launch `tracy-profiler.exe` and press **Connect** (so it attaches as soon as the editor/game starts).
2. Run the Tracy-enabled editor (or export/run a Tracy-enabled release template).
3. When both are running you should see frame data stream in. Press **Stop** when you have enough.

Useful controls: mouse wheel to zoom, right-drag to pan the timeline, and the Frames left/right arrows in the top bar to step one frame. See the [Tracy manual](https://github.com/wolfpld/tracy/releases/latest/download/tracy.pdf) for more.


## Uploading

If the engine has been updated, ensure that a new editor and release template have been compiled. Upload them to the [CustomCompiledGodot](https://drive.google.com/drive/folders/1RcGNdll7p64YjHq86qd5XTMO96mUSSM4?dmr=1&ec=wgc-drive-hero-goto) google drive folder, nested within a dated folder.

Next, login to the Sentry cli with `sentry-cli login`. It brings you to a webpage where you can generate an auth token and paste it into the terminal.

We use Sentry for automatic crash dump uploads. In order for Sentry to parse the crash dumps, we must upload the `.pdb` corresponding to the `.exe` used to run the game. `./build.ps1` does this after the dated folder is written, uploading only that folder:

```
sentry-cli debug-files upload --include-sources --org autotroph-games --project haunted-heist <path_to_this_repo/bin/yyyy-MM-dd>
```

To upload by hand, run that command against the dated folder (or against `/bin` to send every `.pdb` still sitting there).

Note that it is okay to have many `.pdb` files uploaded to Sentry at once, since it can intelligently match the GUID from the executed program to the GUID of the relevant `.pdb`.


# Changelog

Contains all changes made to the engine, from most recent to oldest.

## 10.3.26 IK: fix out-of-bounds crash in deterministic IterateIK3D with an extended end bone

Custom patch (no upstream PR) to `scene/3d/iterate_ik_3d.h`
(`IterateIK3DSetting::init_joints`) and `scene/3d/chain_ik_3d.h`
(`ChainIK3DSetting::cache_current_vectors`). Marked `HAUNTED HEIST PATCH`.
Game-side note in `Haunted-Heist/Docs/Crashes.md`.

Why: a player crashed mid-game with `EXCEPTION_BREAKPOINT` (a `LocalVector`
bounds check, `local_vector.h:206`) in
`ChainIK3D::ChainIK3DSetting::cache_current_vectors` (`chain_ik_3d.h:156`),
reached from `IterateIK3DSetting::init_joints` during
`Skeleton3D::_process_modifiers`. The game's spine IK (`upper_body_IK`, a
`CCDIK3D`) uses `extend_end_bone = true` with the end-bone direction
`FROM_PARENT`, and `PlayerAnimStateMachine` sets `deterministic = true` on it.
In deterministic mode `_init_joints` re-runs `init_joints()` every frame
**without** `_clear_joints()`, so `solver_info_list` keeps last frame's
entries. `init_joints` rebuilds `chain` from scratch: one point per joint plus
one extra point for the end extension — but that extra push is skipped
(`continue`) when `get_bone_axis()` returns a zero axis. With
`mutable_bone_axes` (default on), `FROM_PARENT` derives the axis from the end
bone's *current animated local translation*, so any frame where an animation
or blend zeroes that translation (here: `DEF_head`) skips the extension while
the last joint's solver info is still non-null from earlier frames.
`cache_current_vectors` then reads `chain[joints.size()]` on a chain of only
`joints.size()` points — out of bounds, `CRASH_BAD_INDEX`, game dead.
The dirty (non-deterministic) init path is immune because `_clear_joints()`
nulls the solver list first, which is why only the spine IK crashed.

The patch, two independent halves:

1. `init_joints`: when the end-bone axis is zero, `memdelete` and null the
   last joint's stale solver info before `continue`, so a solver entry can
   never outlive its chain point. It is recreated the next frame the axis is
   valid (fine in deterministic mode, which rebuilds rotations every init).
2. `cache_current_vectors`: break out of the loop when `TAIL` would exceed
   `chain` (or `HEAD` the solver list) instead of trusting `joints.size()`,
   as a defensive guard for any other path that leaves the chain short.

These IK classes come from the upstream Godot 4.6 IK rework
(`IterateIK3D`/`CCDIK3D`/`ChainIK3D`), so the bug very likely exists upstream;
worth checking master and reporting if still present. Rebuild editor + release
template (and the Mac export template, built separately) before this helps
players.

## 10.3.26 Windows: permanently prefer Vulkan after a Direct3D 12 startup crash

Custom patch (no upstream PR) to `platform/windows/display_server_windows.cpp` /
`.h` (constructor, right after the 9.29.26 Wine patch, plus `process_events()`).
Marked `HAUNTED HEIST PATCH`. Game-side note in `Haunted-Heist/Docs/Crashes.md`.

Why: a Windows player crashed on every launch with
`EXCEPTION_ACCESS_VIOLATION_WRITE / 0x90` in
`TextureStorage::_update_render_target` (`texture_storage.cpp:4274`) while the
main scene instantiated its first `PopupMenu`. The real failure is earlier: the
D3D12 driver started refusing `texture_create` mid-load (device removed or
similar), so the render target's placeholder texture RID was never initialized
and the engine wrote through a null `Texture *`. Launching with
`--rendering-driver vulkan` fixed that machine. Since 9.29.26 ships D3D12 as
the Windows default, affected players crash on every default launch with no
way out besides finding the launch option.

The patch: when the driver resolves to `d3d12` and did **not** come from
`--rendering-driver`, write a `user://d3d12_boot_pending` sentinel before the
first D3D12 boot attempt (before device init, which can itself crash broken
drivers). `process_events()` deletes it once 60 frames have been drawn. If the
sentinel is still present at the next launch, the previous D3D12 startup
crashed: a permanent `user://prefer_vulkan` marker is written and the game
prefers Vulkan from then on, keeping D3D12 as a last-resort fallback if Vulkan
fails to initialize. The driver source is reported as
`RENDERING_SOURCE_FALLBACK`. An explicit `--rendering-driver` always wins and
never writes or reads the markers.

The switch is permanent by design: one startup crash flips the machine to
Vulkan forever (no retry per build, no second-strike requirement). Players (or
support) reset it by deleting `user://prefer_vulkan` from the project's user
data folder or launching once with `--rendering-driver d3d12`. Both marker
files are plain text and readable from GDScript, so the game can surface or
report the switch. Known tradeoff: any crash during the first ~60 frames, even
one unrelated to rendering, also flips the machine to Vulkan.

## 9.29.26 Windows: prefer Vulkan over Direct3D 12 under Wine/Proton

Custom patch (no upstream PR) to `platform/windows/display_server_windows.cpp`
(new `_is_running_under_wine()`, used in the `DisplayServerWindows`
constructor before the rendering driver list is built). Marked
`HAUNTED HEIST PATCH`.

Why: the game ships a Windows build only, and Steam Deck runs it through
Proton. D3D12 there goes through vkd3d-proton and doesn't work on the Deck,
so the Steamworks default launch option had to force Vulkan for everyone,
Windows players included. Steamworks can't target a launch option at the Deck,
because under Proton it matches the Windows options.

The patch: if the requested driver is `d3d12`, it did **not** come from
`--rendering-driver` on the command line, and the process is running under
Wine, try Vulkan first, with D3D12 as a last resort. Wine is detected by
`ntdll.dll` exporting `wine_get_version` (native Windows never does), with
`SteamDeck=1` or a non-empty `STEAM_COMPAT_DATA_PATH` as a backup for Wine builds
that hide their exports. The driver source is reported as
`RENDERING_SOURCE_FALLBACK`. Native Windows is unchanged, and an explicit
`--rendering-driver` always wins, on either platform.

After shipping a build with this: remove `--rendering-driver vulkan` from the
default Steamworks launch option so Windows uses the project's D3D12 default.
Optionally add a second launch option ("Play (Vulkan)") for Windows players who
want Vulkan.

## 9.29.26 Vulkan: serialize pipeline cache reads against pipeline creation

Custom patch (no upstream PR) to `drivers/vulkan/rendering_device_driver_vulkan.h`
/ `.cpp`: new `RWLock pipelines_cache_lock`. Marked `HAUNTED HEIST PATCH`.
Game-side note in `Haunted-Heist/Docs/Crashes.md`.

Why: an Intel Windows player crashed with `EXCEPTION_ACCESS_VIOLATION_READ /
0x170` inside `igvk64` (Intel's Vulkan driver), in `vkGetPipelineCacheData`
called from `pipeline_cache_serialize` on the background `PipelineCacheSave`
task. `RenderingDevice::render_pipeline_create` calls the driver outside
`_THREAD_SAFE_METHOD_` so pipelines compile in parallel, so the save can read
the cache while other threads create pipelines through it. Vulkan allows this
(the cache isn't created `EXTERNALLY_SYNCHRONIZED`); Intel's driver evidently
doesn't handle it.

The patch: `vkCreateGraphicsPipelines`, `vkCreateComputePipelines`, and
`CreateRaytracingPipelinesKHR` take the lock shared, so compiles stay parallel.
Both `vkGetPipelineCacheData` calls (`pipeline_cache_query_size`,
`pipeline_cache_serialize`) take it exclusive. The lock only wraps single
Vulkan calls and is never nested, so it can't deadlock. The only new waiting
is compiles pausing for the few ms a mid-game save copies the cache.

Caveat: the crash log only showed the crashing thread, so the race is likely
but not proven. If the crash recurs on this build, the driver is failing in
`vkGetPipelineCacheData` for some other reason; the fallback is raising
`rendering/rendering_device/pipeline_cache/save_chunk_size_mb` so the cache
only saves at exit.

## 9.27.26 RenderingDevice: skip draws and dispatches after a failed pipeline bind

Custom patch (no upstream PR) to `servers/rendering/rendering_device.h` /
`rendering_device.cpp` (`draw_list_bind_render_pipeline`, `draw_list_draw`,
`draw_list_draw_indirect`, `compute_list_bind_compute_pipeline`,
`compute_list_dispatch`, `compute_list_dispatch_indirect`, plus the two
push-constant guards from 9.25.26). Game-side note in
`Haunted-Heist/Docs/Crashes.md`.

Why: the same Intel MacBook Air (Iris Plus, MoltenVK) crashed again on the
9.25.26 build, this time `EXC_BAD_ACCESS` (`KERN_PROTECTION_FAILURE`) in a
`memmove` inside the Apple driver (`IGAccelRenderCommandEncoder::writeVSState`)
while `MVKCmdDrawIndexed::encode` submitted the frame. The 9.25.26 guards only
fired when **no pipeline had ever bound** (null ShaderID). But when a pipeline
bind fails mid-list (`ERR_FAIL_NULL(pipeline)` returns early), the list keeps
the **previous** pipeline's state — non-null, so the guards pass — and the
draw is still recorded. The driver then encodes the draw with a stale pipeline
against freshly bound vertex/uniform buffers sized for a different shader, and
its vertex-state copy runs off the end of a buffer.

The patch adds a `pipeline_bind_failed` flag to draw and compute list state,
set when a bind fails and cleared on any successful bind. Draws, indirect
draws, dispatches, indirect dispatches, and push constants are skipped (with
`ERR_PRINT_ONCE`) while the flag is set or while no pipeline has ever bound.
Valid pipelines are unchanged.

Does **not** make the failing pipelines build on that GPU; whatever they drew
is missing on that machine. Rebuild the Mac export template from this source
and re-export before it helps players. If the crash persists even with no
"skipped" messages in the player's log, the draw had a valid pipeline and this
is a raw Ice Lake Metal driver bug — the remaining option is steering that
hardware to the Compatibility renderer or listing it as unsupported.

## 9.25.26 RenderingDevice: skip push constants / dispatch when no pipeline is bound

Custom patch (no upstream PR) to `servers/rendering/rendering_device.cpp`
(`draw_list_set_push_constant`, `compute_list_set_push_constant`,
`compute_list_dispatch`). Game-side note in `Haunted-Heist/Docs/Crashes.md`.

Why: the same Intel MacBook Air (Iris Plus, MoltenVK) crashed again after the
9.24.26 patch, this time `EXC_BAD_ACCESS` (`KERN_INVALID_ADDRESS at 0x60`) in
`RenderingDeviceDriverVulkan::command_bind_push_constants` during
`RenderingDeviceGraph::_run_render_commands` at end of frame. The player's log
shows 19 compute pipelines failing to create
(`Couldn't create Vulkan compute pipelines (VkResult error -3)`). A failed
`compute_list_bind_compute_pipeline` returns early and leaves
`state.pipeline_shader_driver_id` null. `compute_list_set_push_constant` then
records that null ShaderID into the frame graph (its validation is
DEBUG-only), and the replay dereferences it — 0x60 is a field offset inside
the null `ShaderInfo`.

The patch skips (with `ERR_PRINT_ONCE`) push-constant recording on draw and
compute lists, and `compute_list_dispatch` (whose "no pipeline set" check was
also DEBUG-only and which records uniform-set binds with the same null
ShaderID), whenever no pipeline has ever bound. Valid pipelines are unchanged.

Does **not** make those 19 compute pipelines build on that GPU (`VkResult -3`
from MoltenVK); the affected effects stay missing on that machine. Rebuild the
Mac export template from this source and re-export before it helps players.

## 9.24.26 RenderingDevice: skip compute dispatch when the workgroup size is zero

Custom patch (no upstream PR) to `servers/rendering/rendering_device.cpp`
(`RenderingDevice::compute_list_dispatch_threads`). Game-side note in
`Haunted-Heist/Docs/Crashes.md`.

Why: an Intel MacBook Air (x86_64 slice of the universal Mac export) crashed
with `EXC_ARITHMETIC` (exception 3, code 1, subcode 0 — integer divide by zero)
in `compute_list_dispatch_threads`, called from `CopyEffects::gaussian_glow`
during Forward+ post-processing. That function divides the thread count by
`compute_list.state.local_group_size`. A compute list starts at `{0, 0, 0}`,
and the size is only filled when a compute pipeline binds. The glow pass does
not check that bind. On this GPU the glow compute pipeline does not bind, so
the dispatch divides by zero. A bound pipeline has a workgroup of 8×8×1 and
never hits the check.

The patch returns before the division and prints once:
`Compute dispatch skipped: pipeline local group size is zero.`
Valid pipelines are unchanged. The failed glow dispatch is skipped, so glow
is missing for that pass and the process stays up.

Does **not** make the Intel glow compute pipeline bind. Rebuild the Mac
export template from this source and re-export before it helps players. The
2026-09-16 `macos.zip` does not include this patch.

## 9.16.26 GodotSteam mesh link resilience: connect-phase retries + failure signal

Custom patch (no upstream PR) to `modules/godotsteam/godotsteam_multiplayer_peer.cpp/.h`.
Game-side counterpart documented in `Haunted-Heist/Docs/MeshNetworkResilience.md`.

Why: `SteamMultiplayerPeer` builds a full mesh by opening one direct symmetric
`ConnectP2P` link per pair of lobby members, but a link that failed while still
connecting (NAT punch / relay timeout — the common case in 8-player lobbies with
28 links) was handled completely silently: no retry (upstream only retried
`k_ESteamNetConnectionEnd_Remote_BadCert`), no signal, and the peer never entered
the `peers` map, so broadcasts just skipped it forever. In game this appeared as
two players frozen/silent to each other while everyone else looked fine.

Three changes in `network_connection_status_changed`:

1. **Retry any connect-phase failure**, not just bad certs: old state `Connecting`
   or `FindingRoute` triggers a re-dial via `add_peer()`, capped by the existing
   `connection_retries < 5` counter (reset whenever any link connects), skipped
   when the peer is shutting down or the remote is no longer a lobby member
   (new `_is_lobby_member()` helper).
2. **Erase stale `steam_connections` entries** for connect-phase failures.
   Upstream only erased entries for previously-Connected links, so failed pending
   connections leaked `Ref<SteamPacketPeer>` entries for the session's lifetime.
3. **New signal `peer_connection_failed(steam_id, end_reason, debug_message,
   was_connecting)`** emitted on every link close/failure so the game layer gets
   observability (telemetry + the game-side mesh watchdog). Documented in
   `doc_classes/SteamMultiplayerPeer.xml`.

The game connects to the signal guarded by `has_signal()`, so it runs unchanged on
pre-patch binaries. Rebuild editor + release template (`./build.ps1`) for the
engine-side retry/cleanup/signal to take effect; the game-side watchdog
(`MeshConnectionWatchdog`) provides equivalent re-dial coverage in the meantime.

## 8.31.26 RenderingDevice: null-check uniform sets on compute/raytracing dispatch

Custom patch extending [upstream PR #114073](https://github.com/godotengine/godot/pull/114073)
(which only covered draw lists) to the remaining `_uniform_set_update_shared` call sites.

Why: a Sentry crash (`EXCEPTION_ACCESS_VIOLATION_READ / 0x80`) hit
`RenderingDevice::_uniform_set_update_shared` from `compute_list_dispatch` while
processing a newly spawned `GPUParticles3D`. `uniform_set_owner.get_or_null()`
returned null (stale RID after a particle system was duplicated/freed, or the
uniform set was auto-freed with a dependent resource), and the next line
iterated `p_uniform_set->shared_textures_to_update` on a null pointer. Offset
`0x80` is that `LocalVector` field inside `UniformSet`.

The same `ERR_FAIL_NULL(uniform_set)` already exists on `draw_list_draw` /
`draw_list_draw_indirect` (PR #114073). This adds it to:
* `compute_list_dispatch` (GPUParticles process compute)
* `compute_list_dispatch_indirect`
* raytracing dispatch (same pattern; we do not use RT, included for completeness)

Happy-path cost is one `unlikely()` null compare after a RID lookup already paid.
On failure the dispatch returns, that particle system skips a frame, and the
engine keeps running instead of crashing.

Does **not** fix why the RID went stale. Rebuild editor + release template and
upload the new `.pdb` to Sentry before this helps players.

## 7.22.26 WASAPI audio driver: limit output mixing to stereo

Custom patch (no upstream PR), ported from our 4.6 debug source tree.

Why: Godot mixes audio at the device's channel count, and bus effects are instantiated
once per channel pair. On surround devices (5.1/7.1) this made voice effects 3-4x more
expensive and caused audio lag. The patch replaces the channel-count switch in
`AudioDriverWASAPI::init_output_device` with a hardcoded `channels = 2`, so we always
mix in stereo. The render thread writes the stereo mix to the device's front L/R
channels and zero-fills the rest.

Notes:
* Mono and stereo devices are unaffected (stock Godot already mixed those in stereo).
* Surround devices lose surround output; the game is stereo-only by design.

## 7.22.26 WASAPI audio driver: multi-channel microphone input (mic arrays)

[upstream Open PR](https://github.com/godotengine/godot/pull/101673).

Why: stock Godot only supports 1- or 2-channel capture devices. Laptop built-in microphone
arrays often expose 4 channels, so the capture thread spammed
WASAPI: unsupported channel count in microphone! on every captured frame and produced
silence instead of voice. The patch adds an else if (ad->audio_input.channels >= 2) branch
that downmixes any 3+ channel device to stereo by averaging even channel indices into one
side and odd indices into the other.

Notes:
* 1- and 2-channel microphones are unaffected (their existing branches match first).
* Applied verbatim from the PR, including its quirks (e.g. a dead r += last_sample;
assignment that gets overwritten, and the last channel being dropped from the average
on even channel counts). Kept as-is so we stay in sync with upstream if it merges.


# Troubleshooting

This section logs all issues encountered when trying to set up the build system, for reference if they come up again later.

## 1. Every compile fails instantly with `Error 1` and no compiler error message

Symptom: scons dies within seconds on the very first files (e.g. `console_wrapper_windows.cpp`,
`godot_res_wrap_template`) with `scons: *** [...] Error 1`, but no actual compiler error is printed.
The `.obj` files are actually being created — the compiles are succeeding.

Cause: a corrupted `AutoRun` value in the registry at
`HKCU\Software\Microsoft\Command Processor`. SCons launches every compiler command through
`cmd /c`, and cmd runs the AutoRun command on every startup. If that command fails (e.g. broken
quoting in a `doskey /macrofile=...` line), **every** `cmd /c` invocation reports exit code 1
regardless of whether the real command succeeded, so scons thinks every compile failed.

Verify: in PowerShell run `cmd /c exit 0` then `echo $LASTEXITCODE`. If it prints `1`, this is
the problem. Inspect with:

```
reg query "HKCU\Software\Microsoft\Command Processor" /v AutoRun
```

Fix: repair the quoting of the AutoRun value, or delete it entirely:

```
reg delete "HKCU\Software\Microsoft\Command Processor" /v AutoRun /f
```

(As of July 2026 this machine's AutoRun loads doskey aliases from `%USERPROFILE%\.cmd_aliases.doskey`,
which defines the `upload-demo` alias. Deleting AutoRun removes that alias.)

## 2. GodotSteam fails to compile: `'OS': is not a class or namespace name`

Symptom: build gets through ~750 files, then errors in `modules\godotsteam\godotsteam.cpp` around
the `steamInit` / `start_initialization_verbose` functions:

```
godotsteam.cpp(480): error C2653: 'OS': is not a class or namespace name
godotsteam.cpp(480): error C2039: 'set_environment': is not a member of 'Steam'
```

Cause: `godotsteam.cpp` calls `OS::get_singleton()->set_environment(...)` but doesn't include
`core/os/os.h`. On some source trees the header gets pulled in transitively, so it may compile
fine on one machine and fail on another with a slightly different Godot/GodotSteam version.

Fix: add the include near the top of `modules\godotsteam\godotsteam.cpp`, right after
`#include "godotsteam.h"`:

```cpp
#include "core/os/os.h"
```