param(
  [string]$VcVars = 'C:\BuildTools\VC\Auxiliary\Build\vcvars64.bat',
  [Parameter(Mandatory=$true)][string]$Sdk,
  [Parameter(Mandatory=$true)][string]$RuntimeTools,
  [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$Sdk = [IO.Path]::GetFullPath($Sdk)
$RuntimeTools = [IO.Path]::GetFullPath($RuntimeTools)
if (-not (Test-Path -LiteralPath "$Sdk\RED4ext\RED4ext.hpp")) { throw 'RED4ext SDK headers required / Нужны заголовки SDK' }
if (-not (Test-Path -LiteralPath $VcVars)) { throw 'MSVC x64 tools required / Нужен MSVC x64' }
$buildDir = Join-Path $projectRoot 'build'
$distDir = if ($OutputDirectory) { [IO.Path]::GetFullPath($OutputDirectory) } else { Join-Path $projectRoot 'dist' }
if ((Test-Path -LiteralPath $distDir) -and (Get-ChildItem -LiteralPath $distDir -Force)) { throw 'Use an empty output directory / Нужна пустая папка результата' }
New-Item -ItemType Directory -Force $buildDir,$distDir | Out-Null
$nativeBuild = "@call `"$VcVars`" >nul 2>nul`r`n@cd /d `"$buildDir`"`r`ncl /nologo /O2 /DNDEBUG /LD /EHsc /std:c++20 /utf-8 /W3 /I`"$Sdk`" /I`"$projectRoot\bridge`" `"$projectRoot\bridge\Plugin.cpp`" /link /OUT:CheatKitRED.dll user32.lib`r`n@exit /b %errorlevel%"
Set-Content -LiteralPath "$buildDir\native.bat" -Value $nativeBuild -Encoding ASCII
cmd /c "$buildDir\native.bat"
if ($LASTEXITCODE -ne 0) { throw 'Native build failed / Ошибка сборки плагина' }
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $csc /nologo /target:exe "/out:$buildDir\IconGen.exe" /r:System.Drawing.dll "$projectRoot\src\IconGen.cs"
if ($LASTEXITCODE -ne 0) { throw 'Icon generator build failed' }
& "$buildDir\IconGen.exe" "$projectRoot\assets" V 238 219 46
if ($LASTEXITCODE -ne 0) { throw 'Icon generation failed' }
& $csc /nologo /codepage:65001 /target:winexe /platform:x64 /optimize+ "/out:$distDir\Cyberpunk2077Trainer.exe" `
  "/win32icon:$projectRoot\assets\icon.ico" "/win32manifest:$projectRoot\src\app.manifest" `
  "/resource:$projectRoot\assets\icon.png,icon.png" /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll `
  "$projectRoot\src\Shell.cs" "$projectRoot\src\Link.cs" "$projectRoot\src\Game.cs" "$projectRoot\src\Bindings.cs" "$projectRoot\src\Tools.cs" "$projectRoot\src\CyberwareSlots.cs" "$projectRoot\src\VehicleEditor.cs" "$projectRoot\src\AutodriveEditor.cs"
if ($LASTEXITCODE -ne 0) { throw 'UI build failed / Ошибка сборки интерфейса' }
Copy-Item -LiteralPath "$projectRoot\mod" -Destination $distDir -Recurse
New-Item -ItemType Directory -Force "$distDir\mod\red4ext\plugins\CheatKit" | Out-Null
Copy-Item -LiteralPath "$buildDir\CheatKitRED.dll" -Destination "$distDir\mod\red4ext\plugins\CheatKit\CheatKitRED.dll"
foreach ($runtime in 'cet-runtime','red4ext-runtime','redscript-runtime') {
  if (-not (Test-Path -LiteralPath "$RuntimeTools\$runtime")) { throw "Missing dependency / Нет зависимости: $runtime" }
  New-Item -ItemType Directory -Force "$distDir\dependencies\$runtime" | Out-Null
  Copy-Item -Path "$RuntimeTools\$runtime\*" -Destination "$distDir\dependencies\$runtime" -Recurse
}
foreach ($document in 'README.md','Install.ps1','Setup.ps1','INSTALL.cmd','UNINSTALL.cmd','LICENSE','VERIFY.md') {
  Copy-Item -LiteralPath "$projectRoot\$document" -Destination "$distDir\$document"
}
Copy-Item -LiteralPath "$projectRoot\licenses" -Destination $distDir -Recurse
foreach ($folder in 'assets','ports','tools','docs') {
  Copy-Item -LiteralPath "$projectRoot\$folder" -Destination $distDir -Recurse
}
$manifest = Get-ChildItem -LiteralPath $distDir -Recurse -File | Sort-Object FullName | ForEach-Object {
  $relative = $_.FullName.Substring($distDir.Length+1).Replace('\','/')
  "$( (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant() )  $relative"
}
Set-Content -LiteralPath "$distDir\SHA256SUMS.txt" -Value $manifest -Encoding ASCII
Get-Item -LiteralPath "$distDir\Cyberpunk2077Trainer.exe","$distDir\mod\red4ext\plugins\CheatKit\CheatKitRED.dll" | Select-Object Name,Length
