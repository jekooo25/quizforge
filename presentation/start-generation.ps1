$project = Split-Path -Parent $PSScriptRoot
$python = Join-Path $env:USERPROFILE 'Tools/qfenv/Scripts/python.exe'
if (!(Test-Path -LiteralPath $python)) { Write-Host 'Quiz generation environment was not found.'; Read-Host 'Press Enter'; exit 1 }
$env:QF_PORT = '8765'
Write-Host 'Keep this window open while generating quizzes. Sharing uses a separate server window.'
& $python -X utf8 (Join-Path $project 'server/app.py')
Read-Host 'Press Enter to close'
