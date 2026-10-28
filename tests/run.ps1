param([string]$Lua = 'lua')
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    # Lua 5.3/5.4, or texlua.exe from an existing TeX installation.
    & $Lua (Join-Path $PSScriptRoot 'run.lua')
    if ($LASTEXITCODE -ne 0) { throw "Lua tests failed ($LASTEXITCODE)" }
} finally { Pop-Location }
