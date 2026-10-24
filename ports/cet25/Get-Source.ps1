param([string]$Destination = '')
$ErrorActionPreference = 'Stop'
if (-not $Destination) { $Destination = Join-Path $PSScriptRoot '..\..\deps\cet25' }
if (Test-Path -LiteralPath $Destination) { throw 'Destination exists / Папка уже существует' }
git clone -c core.autocrlf=false https://github.com/maximegmd/CyberEngineTweaks.git $Destination
if ($LASTEXITCODE -ne 0) { throw 'Clone failed' }
git -C $Destination checkout 81d097e249d4f92665df2d46df5c05ed282419c9
if ($LASTEXITCODE -ne 0) { throw 'Checkout failed' }
git -c core.autocrlf=false -C $Destination submodule update --init vendor/RED4ext.SDK
if ($LASTEXITCODE -ne 0) { throw 'SDK submodule failed' }
git -C $Destination apply --whitespace=nowarn (Join-Path $PSScriptRoot 'cet.patch')
if ($LASTEXITCODE -ne 0) { throw 'CET patch failed' }
git -C (Join-Path $Destination 'vendor\RED4ext.SDK') apply --whitespace=nowarn (Join-Path $PSScriptRoot 'sdk.patch')
if ($LASTEXITCODE -ne 0) { throw 'SDK patch failed' }
foreach ($name in 'Local25Addresses.h','Local25Build.h','Local25GameInstance.h') {
  Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination (Join-Path $Destination 'src\reverse')
}
Write-Output 'Source ready. Run xmake f -m release, then xmake -y in the destination.'
