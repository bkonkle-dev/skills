#Requires -Version 5.1
<#
.SYNOPSIS
    Skills repo installer for Windows (PowerShell equivalent of setup.sh).
.DESCRIPTION
    Symlinks skills, statusline, and hooks from this repo into ~/.claude/.
    Idempotent — safe to run repeatedly.

    Requires either Developer Mode enabled or an elevated (admin) prompt,
    because New-Item -ItemType SymbolicLink needs SeCreateSymbolicLinkPrivilege.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'

# Ensure ~/.claude/ directories exist
New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'skills') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'hooks') | Out-Null

# ── Helper ────────────────────────────────────────────────────────────────

function Install-Symlink {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label
    )

    if (Test-Path $Destination) {
        $item = Get-Item $Destination -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            # Already a symlink — remove and recreate
            Remove-Item $Destination -Force
        } else {
            # Regular file or directory — back it up
            $backup = "$Destination.bak"
            Write-Host "Backing up existing $Destination -> $backup"
            Move-Item $Destination $backup -Force
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Destination -Target $Source | Out-Null
    } catch [System.UnauthorizedAccessException] {
        Write-Host ''
        Write-Host 'Error: Symlink creation failed — insufficient privileges.' -ForegroundColor Red
        Write-Host 'Enable Developer Mode (Settings > For developers) or run as Administrator.'
        exit 1
    }
    Write-Host "  $Label -> $Source"
}

# ── Statusline ────────────────────────────────────────────────────────────

$statuslineSrc = Join-Path (Join-Path $ScriptDir 'statusline') 'statusline.sh'
$statuslineDst = Join-Path $ClaudeDir 'statusline.sh'

if (Test-Path $statuslineSrc) {
    Install-Symlink -Source $statuslineSrc -Destination $statuslineDst -Label 'statusline'
}

# ── Skills ────────────────────────────────────────────────────────────────

$skillsDir = Join-Path $ScriptDir 'skills'
Get-ChildItem -Directory $skillsDir | ForEach-Object {
    $src = $_.FullName
    $dst = Join-Path (Join-Path $ClaudeDir 'skills') $_.Name
    Install-Symlink -Source $src -Destination $dst -Label "skill/$($_.Name)"
}

# ── Hooks ─────────────────────────────────────────────────────────────────

$hooksDir = Join-Path $ScriptDir 'hooks'
if (Test-Path $hooksDir) {
    Get-ChildItem -File $hooksDir | ForEach-Object {
        $src = $_.FullName
        $dst = Join-Path (Join-Path $ClaudeDir 'hooks') $_.Name
        Install-Symlink -Source $src -Destination $dst -Label "hook/$($_.Name)"
    }
}

# ── Summary ───────────────────────────────────────────────────────────────

Write-Host ''
Write-Host "Done. Skills installed via symlinks from:"
Write-Host "  $ScriptDir"
Write-Host ''
Write-Host 'To update skills, pull this repo — symlinks auto-reflect changes.'
Write-Host 'To add a new skill, run setup.ps1 again after adding it.'
