#!/bin/bash
# macOS counterpart of build.ps1.
# Builds the godotroph editor (arm64) and a universal release template, then
# moves the results into a dated subfolder of bin/ (e.g. bin/2026-09-17),
# including a packaged macos.zip export template with libsteam_api.dylib
# bundled (required by the built-in GodotSteam module).
set -euo pipefail
cd "$(dirname "$0")"

scons platform=macos arch=arm64 target=editor debug_symbols=yes
# lto=thin instead of the Windows script's lto=full: full LTO's link step gets
# OOM-killed on this 8 GB machine. Thin LTO links within memory limits with
# near-identical runtime performance.
# separate_debug_symbols=yes strips the binary and emits symbols separately
# (macOS equivalent of the .pdb setup on Windows, needed by Sentry).
# The find-delete between the two arch builds frees ~5 GB of objects; this
# machine's disk is too tight to hold both object trees at once.
scons platform=macos arch=arm64 target=template_release debug_symbols=yes separate_debug_symbols=yes lto=thin optimize=speed
find bin/obj -name "*template_release.arm64*" -delete
scons platform=macos arch=x86_64 target=template_release debug_symbols=yes separate_debug_symbols=yes lto=thin optimize=speed
find bin/obj -name "*template_release.x86_64*" -delete

OUT_DIR="bin/$(date +%Y-%m-%d)"
mkdir -p "$OUT_DIR"

# Merge the two template builds into one universal binary.
lipo -create \
    bin/godot.macos.template_release.arm64 \
    bin/godot.macos.template_release.x86_64 \
    -output bin/godot_macos_release.universal

# Package the macOS export template: .app skeleton from misc/dist, the
# universal binary, and the Steam API dylib next to it.
rm -rf "$OUT_DIR/macos_template.app" "$OUT_DIR/macos.zip"
cp -R misc/dist/macos_template.app "$OUT_DIR/macos_template.app"
mkdir -p "$OUT_DIR/macos_template.app/Contents/MacOS"
cp bin/godot_macos_release.universal "$OUT_DIR/macos_template.app/Contents/MacOS/godot_macos_release.universal"
chmod +x "$OUT_DIR/macos_template.app/Contents/MacOS/godot_macos_release.universal"
cp modules/godotsteam/sdk/redistributable_bin/osx/libsteam_api.dylib "$OUT_DIR/macos_template.app/Contents/MacOS/"
(cd "$OUT_DIR" && zip -q -9 -r macos.zip macos_template.app && rm -rf macos_template.app)

# Move binaries into the dated folder (mirrors the Windows script).
mv bin/godot.macos.editor.arm64 "$OUT_DIR/"
mv bin/godot.macos.template_release.arm64 "$OUT_DIR/"
mv bin/godot.macos.template_release.arm64.dSYM "$OUT_DIR/"
mv bin/godot.macos.template_release.x86_64 "$OUT_DIR/"
mv bin/godot.macos.template_release.x86_64.dSYM "$OUT_DIR/"
mv bin/godot_macos_release.universal "$OUT_DIR/"

# The editor links libsteam_api.dylib via @loader_path (like steam_api64.dll
# sitting next to the Windows editor exe).
cp modules/godotsteam/sdk/redistributable_bin/osx/libsteam_api.dylib "$OUT_DIR/"

echo "Build artifacts moved to $OUT_DIR"
