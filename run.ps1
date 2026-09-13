param([switch]$Build, [switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if ($Build -or -not (Test-Path 'bin/voxel_footprint.windows.template_debug.x86_64.dll')) {
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize godot-cpp.' }
    py -m SCons platform=windows target=template_debug
    if ($LASTEXITCODE -ne 0) { throw 'Build failed. Install Visual Studio C++ tools and py -m pip install scons.' }
}
$godotCommand = Get-Command godot -ErrorAction SilentlyContinue
$godotExecutable = if ($godotCommand) { $godotCommand.Source } else {
    Get-ChildItem "$env:LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*" -Filter 'Godot*_win64.exe' -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godotExecutable) { throw 'Godot was not found. Add Godot 4.5+ to PATH.' }
if ($SelfTest) {
    $testProcess = Start-Process -FilePath $godotExecutable -ArgumentList '--path', ('"' + $PSScriptRoot + '"'), '--', '--self-test' -PassThru -Wait -WindowStyle Hidden
    if ($testProcess.ExitCode -ne 0) { throw 'Renderer self-test failed.' }
}
else { & $godotExecutable --path $PSScriptRoot }
