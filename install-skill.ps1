#Requires -Version 5.1
<#
.SYNOPSIS
    Single skill installer for Windows (PowerShell equivalent of install-skill.sh).
.DESCRIPTION
    Symlinks one skill from this repo into ~/.claude/skills/.

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
$ClaudeDir = Join-Path $env:USERPROFILE '.claude'
$SkillsDir = Join-Path $ScriptDir 'skills'

function Show-Usage {
    Write-Host "Usage: .\install-skill.ps1 <skill-name>"
    Write-Host ''
    Write-Host 'Available skills:'
    Get-ChildItem -Directory $SkillsDir | ForEach-Object {
        $skillMd = Join-Path $_.FullName 'SKILL.md'
        $desc = ''
        if (Test-Path $skillMd) {
            $desc = (Select-String -Path $skillMd -Pattern '^description:' | Select-Object -First 1) -replace '^.*description:\s*', ''
        }
        '  {0,-20} {1}' -f $_.Name, $desc
    }
    exit 1
}

if (-not $SkillName) {
    Show-Usage
}

$src = Join-Path $SkillsDir $SkillName

if (-not (Test-Path $src -PathType Container)) {
    Write-Host "Error: skill '$SkillName' not found in $SkillsDir\"
    Write-Host ''
    Show-Usage
}

New-Item -ItemType Directory -Force -Path (Join-Path $ClaudeDir 'skills') | Out-Null
$dst = Join-Path $ClaudeDir "skills\$SkillName"

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

New-Item -ItemType SymbolicLink -Path $dst -Target $src | Out-Null
Write-Host "  skill/$SkillName -> $src"
