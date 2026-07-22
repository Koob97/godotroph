# Builds the godotroph editor and release template, then moves the results
# into a dated subfolder of /bin (e.g. bin/2026-07-22) ready for upload.
$ErrorActionPreference = "Stop"

scons platform=windows target=editor debug_symbols=yes -j12
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

scons platform=windows target=template_release debug_symbols=yes lto=full optimize=speed
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$outDir = Join-Path "bin" (Get-Date -Format "yyyy-MM-dd")
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# Editor + release template binaries, their console wrappers, and the .pdbs
# needed by Sentry. (.exp/.lib linker byproducts are left behind.)
Move-Item -Force -Path "bin\godot.windows.*.exe", "bin\godot.windows.*.pdb" -Destination $outDir

# The D3D12 Agility SDK runtime must sit next to the executables.
Copy-Item -Force -Path "bin\D3D12Core.dll", "bin\d3d12SDKLayers.dll" -Destination $outDir

Write-Host "Build artifacts moved to $outDir"
