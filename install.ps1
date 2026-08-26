# Copyright (C) 2026 Fiber
#
# This Source Code Form is subject to the terms of the Mozilla Public License,
# v. 2.0. If a copy of the MPL was not distributed with this file, You can
# obtain one at https://mozilla.org/MPL/2.0/.
#
# What you may do:
# - Use this software for any purpose, including commercially, and build and
#   sell your own products on top of it.
# - Change it, and create new works based on it.
# - Distribute copies of it, with or without your changes.
# - Combine it with files under any other licence, proprietary ones included,
#   and licence that larger work on your own terms.
#
# What you must do in return:
# - Keep this notice on every file you received it on.
# - Publish, under these same terms, the source of every file covered by them
#   that you distribute, including the ones you changed, so that whoever
#   receives your version can obtain that source.
# - Leave Fiber out of it: the name "Fiber", its branding, its logos and its
#   trademarks may not be used to endorse or promote what you build, and this
#   licence grants no right to them.
#
# Disclaimer:
# AS FAR AS THE LAW ALLOWS, THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY
# OR CONDITION OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR
# NON-INFRINGEMENT. IN NO EVENT SHALL FIBER BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT
# LIMITED TO LOSS OF USE, DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT
# OF OR RELATED TO THESE TERMS OR THE USE OR NATURE OF THE SOFTWARE, UNDER ANY
# KIND OF LEGAL CLAIM.
#
# This header is a summary written for convenience. Where it differs from the

# The PowerShell half of install.sh, for a Windows that has no sh.
#
#   irm https://raw.githubusercontent.com/d-fiber/scribe_tools/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$Repository = if ($env:SCRIBE_REPOSITORY) { $env:SCRIBE_REPOSITORY } else { 'd-fiber/scribe' }
$Branch = if ($env:SCRIBE_BRANCH) { $env:SCRIBE_BRANCH } else { 'main' }
$ToolsRepository = if ($env:SCRIBE_TOOLS_REPOSITORY) { $env:SCRIBE_TOOLS_REPOSITORY } else { 'd-fiber/scribe_tools' }

$Binaries = @('scribe_linux', 'scribe_macos', 'scribe_windows.exe')
$Launchers = @('scribe', 'scribe.cmd')
$TemplatesAsset = 'scribe-templates.tar.gz'

function Fail($message) {
  Write-Error $message
  exit 1
}

function Test-ScribeCheckout($path) {
  return (Test-Path (Join-Path $path '.git')) -and
         (Test-Path (Join-Path $path 'tools')) -and
         (Test-Path (Join-Path $path 'deno.json')) -and
         (Test-Path (Join-Path $path 'engine'))
}

function Find-Or-Clone {
  $candidate = if ($env:SCRIBE_DIRECTORY) { $env:SCRIBE_DIRECTORY } elseif (Test-ScribeCheckout (Get-Location).Path) { (Get-Location).Path } else { $null }

  if ($candidate -and (Test-ScribeCheckout $candidate)) {
    Write-Host "Installing into the checkout at $candidate"
    return (Resolve-Path $candidate).Path
  }

  $root = if ($env:SCRIBE_DIRECTORY) { $env:SCRIBE_DIRECTORY } else { Join-Path (Get-Location).Path 'scribe' }

  if (Test-Path (Join-Path $root '.git')) {
    Write-Host "Reusing the clone at $root"
    return (Resolve-Path $root).Path
  }

  if (Test-Path $root) { Fail "$root already exists and is not a scribe clone" }

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail 'Needs git. Install it from https://git-scm.com/downloads'
  }

  Write-Host "Cloning $Repository into $root"
  git clone --branch $Branch --depth 1 "https://github.com/$Repository.git" $root
  if ($LASTEXITCODE -ne 0) { Fail "git clone failed" }

  return (Resolve-Path $root).Path
}

function Get-Asset($asset, $target) {
  if (Test-Path $target) { Remove-Item $target -Force }
  $url = "https://github.com/$ToolsRepository/releases/latest/download/$asset"
  try {
    Invoke-WebRequest -Uri $url -OutFile $target -UseBasicParsing
  } catch {
    Fail "Could not download $asset from the latest release of $ToolsRepository"
  }
}

$Root = Find-Or-Clone
$Destination = Join-Path $Root 'tools'
New-Item -ItemType Directory -Force -Path $Destination | Out-Null

Write-Host ''
Write-Host "Fetching the tools from the latest release of $ToolsRepository"

foreach ($asset in ($Binaries + $Launchers)) {
  Write-Host "  $asset"
  Get-Asset $asset (Join-Path $Destination $asset)
}

foreach ($binary in $Binaries) {
  $path = Join-Path $Destination $binary
  if ((Get-Item $path).Length -eq 0) { Fail "$binary came down empty" }
}

Write-Host "  $TemplatesAsset"
$archive = Join-Path $Destination $TemplatesAsset
Get-Asset $TemplatesAsset $archive

$templates = Join-Path $Destination 'templates'
if (Test-Path $templates) { Remove-Item $templates -Recurse -Force }
tar -xzf $archive -C $Destination
if ($LASTEXITCODE -ne 0) { Fail "could not unpack $TemplatesAsset. Windows 10 1803 and later ship tar." }
Remove-Item $archive -Force

if (-not (Test-Path (Join-Path $templates 'project'))) { Fail "$TemplatesAsset carried no templates/project/" }

Write-Host ''
Write-Host "Ready. Everything is in $Destination"
Write-Host ''
Write-Host 'The three builds sit side by side and scribe.cmd starts the one this machine runs.'
Write-Host 'Put that directory on your PATH, once, and typing scribe finds it:'
Write-Host "  setx PATH `"$Destination;`$env:PATH`""
Write-Host ''
Write-Host 'None of this is committed, so run it again after pulling a release that'
Write-Host 'rebuilt the tools.'
