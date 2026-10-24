param([string]$Destination = '')
$ErrorActionPreference = 'Stop'
if (-not $Destination) { $Destination = Join-Path $PSScriptRoot '..\deps\bridge-sdk' }
if (Test-Path -LiteralPath $Destination) { throw 'Destination exists / Папка уже существует' }
git clone -c core.autocrlf=false https://github.com/wopss/RED4ext.SDK.git $Destination
if ($LASTEXITCODE -ne 0) { throw 'Clone failed' }
git -C $Destination checkout f9ad5334362a8a0815baf58f47615697485feb52
if ($LASTEXITCODE -ne 0) { throw 'Checkout failed' }
git -C $Destination apply --whitespace=nowarn (Join-Path $PSScriptRoot 'bridge-sdk.patch')
if ($LASTEXITCODE -ne 0) { throw 'SDK patch failed' }
