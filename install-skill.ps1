#Requires -Version 5.1
<#
.SYNOPSIS
    Single skill installer for Windows (PowerShell equivalent of install-skill.sh).
.DESCRIPTION
    Symlinks one skill from this repo into ~/.claude/skills/ and ~/.codex/skills/.

    Requires either Developer Mode enabled or an elevated (admin) prompt,
    because New-Item -ItemType SymbolicLink needs SeCreateSymbolicLinkPrivilege.
.PARAMETER SkillName
    Name of the skill directory under skills/ to install.
.EXAMPLE
    .\install-skill.ps1 pick-up-issue
#>

param(
    [Parameter(Position = 0)]
    [string]$SkillName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetRoots = @(
    (Join-Path $env:USERPROFILE '.claude'),
    (Join-Path $env:USERPROFILE '.codex')
)
$SkillsDir = Join-Path $ScriptDir 'skills'

function Show-Usage {
    Write-Host "Usage: .\install-skill.ps1 <skill-name>"
    Write-Host ''
    Write-Host 'Available skills:'
    Get-ChildItem -Directory $SkillsDir | ForEach-Object {
        $skillMd = Join-Path $_.FullName 'SKILL.md'
        if (-not (Test-Path $skillMd)) {
            return
        }
        $desc = (Select-String -Path $skillMd -Pattern '^description:' | Select-Object -First 1) -replace '^.*description:\s*', ''
        $argHint = (Select-String -Path $skillMd -Pattern '^argument-hint:' | Select-Object -First 1) -replace '^.*argument-hint:\s*', ''
        if (-not $argHint) { $argHint = '-' }
        '  {0,-20} {1,-28} {2}' -f $_.Name, "arg: $argHint", $desc
    }
    Write-Host ''
    Write-Host 'After running setup.ps1, see ~/.claude/skills/INDEX.md or ~/.codex/skills/INDEX.md'
    exit 1
}

if (-not $SkillName) {
    Show-Usage
}

if ($SkillName -match '[/\\]') {
    Write-Host "Error: skill name must not contain path separators."
    exit 1
}

$src = Join-Path $SkillsDir $SkillName

if (-not (Test-Path $src -PathType Container)) {
    Write-Host "Error: skill '$SkillName' not found in $SkillsDir\"
    Write-Host ''
    Show-Usage
}

if (-not (Test-Path (Join-Path $src 'SKILL.md'))) {
    Write-Host "Error: '$SkillName' is missing SKILL.md"
    exit 1
}

foreach ($targetRoot in $TargetRoots) {
    New-Item -ItemType Directory -Force -Path (Join-Path $targetRoot 'skills') | Out-Null
    $dst = Join-Path (Join-Path $targetRoot 'skills') $SkillName

    if (Test-Path $dst) {
        $item = Get-Item $dst -Force
        if ($item.LinkType -eq 'SymbolicLink') {
            Remove-Item $dst -Force
        } else {
            $backup = "$dst.bak"
            Write-Host "Backing up existing $dst -> $backup"
            Move-Item $dst $backup -Force
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
    } catch [System.UnauthorizedAccessException] {
        Write-Host ''
        Write-Host 'Error: Symlink creation failed — insufficient privileges.' -ForegroundColor Red
        Write-Host 'Enable Developer Mode (Settings > For developers) or run as Administrator.'
        exit 1
    }

    Write-Host "  $($targetRoot.Split([IO.Path]::DirectorySeparatorChar)[-1])/skill/$SkillName -> $src"
}
