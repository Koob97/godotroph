# Builds the godotroph editor and release template, moves the results into a
# dated subfolder of /bin (e.g. bin/2026-07-22), then uploads that folder's
# .pdb files to Sentry.
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

# Sentry matches crash dumps to these PDBs by GUID. Upload only this build's
# folder so older PDBs left in bin/ are not sent again.
Write-Host "Uploading debug files to Sentry from $outDir"
sentry-cli debug-files upload --include-sources --org autotroph-games --project haunted-heist $outDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
