param([ValidateSet('server','teacher','student')][string]$Mode)
$project = Split-Path -Parent $PSScriptRoot
if ($Mode -eq 'server') {
    $python = Join-Path $env:USERPROFILE 'Tools\qfenv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python)) { Write-Host 'Python environment not found. Ask your developer to configure the Python path.'; Read-Host 'Press Enter'; exit 1 }
    $env:QF_SHARING_DB = Join-Path $PSScriptRoot 'sharing-demo.sqlite3'
    Write-Host 'Keep this window open during the presentation. Close it to stop sharing.'
    & $python -X utf8 (Join-Path $project 'server\sharing_server.py')
    Read-Host 'Press Enter to close'
    exit
}
$godot = Join-Path $env:USERPROFILE 'Tools\Godot\godot_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { Write-Host 'Godot was not found.'; Read-Host 'Press Enter'; exit 1 }
$env:APPDATA = Join-Path $PSScriptRoot ('sessions\' + $Mode)
[IO.Directory]::CreateDirectory($env:APPDATA) | Out-Null
if ($Mode -eq 'teacher') {
    & $godot --path $project --resolution 800x360 --position 40,80 --max-fps 60 res://presentation/demo.tscn -- --teacher
} else {
    & $godot --path $project --resolution 800x360 --position 160,180 --max-fps 60 res://presentation/demo.tscn
}
