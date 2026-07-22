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


## Uploading

If the engine has been updated, ensure that a new editor and release template have been compiled. Upload them to the [CustomCompiledGodot](https://drive.google.com/drive/folders/1RcGNdll7p64YjHq86qd5XTMO96mUSSM4?dmr=1&ec=wgc-drive-hero-goto) google drive folder, nested within a dated folder.

Next, login to the Sentry cli with `sentry-cli login`. It brings you to a webpage where you can generate an auth token and paste it into the terminal.

We use Sentry for automatic crash dump uploads. In order for Sentry to parse the crash dumps, we must upload the `.pdb` corresponding to the `.exe` used to run the game. In practice, this means uploading the `.pdb` outputted alongside the release template. To do this, run 
```
sentry-cli debug-files upload --include-sources --org autotroph-games --project haunted-heist <path_to_this_repo/bin>
```

This will ensure that any `.pdb` in the `/bin` directory is uploaded to Sentry.

Note that it is okay to have many `.pdb` files uploaded to Sentry at once, since it can intelligently match the GUID from the executed program to the GUID of the relevant `.pdb`.


# Changelog

Contains all changes made to the engine, from most recent to oldest.

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