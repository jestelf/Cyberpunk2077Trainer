param(
  [ValidateSet('Plan','Install','Uninstall')][string]$Action = 'Plan',
  [Parameter(Mandatory=$true)][string]$GamePath,
  [switch]$IncludeDependencies
)
$ErrorActionPreference = 'Stop'
$expectedExe = 'd36e74c47592e9c656ae250078cb40b2be63c782af5bfbeff2280d43e653fab4'
$packageRoot = $PSScriptRoot
$targetRoot = [IO.Path]::GetFullPath($GamePath).TrimEnd('\')
$stateRoot = Join-Path $env:LOCALAPPDATA 'Cyberpunk2077Trainer\installation'
$activeFile = Join-Path $stateRoot 'active.json'

function Hash([string]$Path) {
  if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
  return ''
}
function Target([string]$Relative) {
  $resolved = [IO.Path]::GetFullPath((Join-Path $targetRoot $Relative))
  if (-not $resolved.StartsWith($targetRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes game directory / Путь выходит за папку игры' }
  $part = $resolved
  while ($part) {
    if (Test-Path -LiteralPath $part) {
      if ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Links are not supported / Ссылки не поддерживаются: $part" }
    }
    $part = [IO.Path]::GetDirectoryName($part)
  }
  return $resolved
}
function AssertClosed {
  foreach ($process in Get-Process -Name 'Cyberpunk2077','REDprelauncher' -ErrorAction SilentlyContinue) {
    if (-not $process.Path -or $process.Path.StartsWith($targetRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Close the game and launcher first / Сначала закройте игру и лаунчер' }
  }
}
function SaveState($State) {
  $tempFile = $activeFile + '.new'
  $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tempFile -Encoding UTF8
  Move-Item -LiteralPath $tempFile -Destination $activeFile -Force
}
function Restore($State) {
  if (-not [string]::Equals($State.gamePath, $targetRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Installation belongs to another game directory / Установка относится к другой папке игры' }
  foreach ($entry in $State.entries) {
    $dest = Target $entry.relative
    $currentHash = Hash $dest
    if ($currentHash -and $currentHash -ne $entry.installedHash -and $currentHash -ne $entry.originalHash) { throw "File changed after installation; kept intact / Файл изменён после установки и сохранён: $dest" }
    if ($entry.originalHash -and (Hash $entry.backup) -ne $entry.originalHash) { throw "Backup checksum mismatch / Повреждена резервная копия: $($entry.relative)" }
  }
  foreach ($entry in $State.entries) {
    $dest = Target $entry.relative
    if ($entry.originalHash) {
      [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)) | Out-Null
      Copy-Item -LiteralPath $entry.backup -Destination $dest -Force
    } elseif (Test-Path -LiteralPath $dest -PathType Leaf) {
      Remove-Item -LiteralPath $dest -Force
    }
  }
  $State.status = 'removed'
  $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $State.backupRoot 'receipt.json') -Encoding UTF8
  Remove-Item -LiteralPath $activeFile -Force
}

if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) { throw 'Game directory missing / Нет папки игры' }
if ($Action -eq 'Uninstall') {
  AssertClosed
  if (-not (Test-Path -LiteralPath $activeFile)) { throw 'No managed installation found / Управляемая установка не найдена' }
} else {
  if ((Hash (Target 'bin\x64\Cyberpunk2077.exe')) -ne $expectedExe) { throw 'Unsupported EXE; exact Steam 2.5 build required / Неподдерживаемый EXE; нужна точная сборка Steam 2.5' }
  if (Test-Path -LiteralPath $activeFile) { throw 'An installation exists; uninstall it before replacing / Установка уже есть; перед заменой выполните Uninstall' }
}

$plan = @()
if ($Action -ne 'Uninstall') {
  $checksums = @{}
  foreach ($line in Get-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS.txt')) {
    if ($line -match '^([a-f0-9]{64})  (.+)$') { $checksums[$matches[2].Replace('/','\')] = $matches[1] }
  }
  $sources = @(@{root=(Join-Path $packageRoot 'mod');dependency=$false})
  if ($IncludeDependencies) {
    foreach ($runtime in 'cet-runtime','red4ext-runtime','redscript-runtime') {
      $sources += @{root=(Join-Path $packageRoot "dependencies\$runtime");dependency=$true}
    }
  } else {
    foreach ($required in 'bin\x64\plugins\cyber_engine_tweaks.asi','red4ext\RED4ext.dll','engine\tools\scc.exe') {
      if (-not (Test-Path -LiteralPath (Target $required))) { throw 'Dependencies missing: use -IncludeDependencies / Нет зависимостей: добавьте -IncludeDependencies' }
    }
  }
  $seen = @{}
  foreach ($source in $sources) {
    if (-not (Test-Path -LiteralPath $source.root -PathType Container)) { throw "Package folder missing / Неполный пакет: $($source.root)" }
    foreach ($file in Get-ChildItem -LiteralPath $source.root -Recurse -File) {
      $relative = $file.FullName.Substring($source.root.Length + 1)
      if ($seen.ContainsKey($relative)) { throw "Duplicate target / Повтор пути: $relative" }
      $seen[$relative] = $true
      $packageRelative = $file.FullName.Substring($packageRoot.Length + 1)
      $newHash = Hash $file.FullName
      if (-not $checksums.ContainsKey($packageRelative) -or $checksums[$packageRelative] -ne $newHash) { throw "Package checksum mismatch / Контрольная сумма пакета не совпала: $packageRelative" }
      $dest = Target $relative
      if (Test-Path -LiteralPath $dest -PathType Container) { throw "Destination is a folder / На месте файла папка: $dest" }
      $oldHash = Hash $dest
      if ($source.dependency -and $oldHash -and $oldHash -ne $newHash) { throw "Existing dependency differs; kept intact / Установленная зависимость отличается и сохранена: $relative" }
      if ($oldHash -eq $newHash) { continue }
      $plan += [pscustomobject]@{relative=$relative;source=$file.FullName;installedHash=$newHash;originalHash=$oldHash;backup=''}
    }
  }
  if ($Action -eq 'Plan') {
    $plan | Select-Object relative,@{n='Operation / Действие';e={if ($_.originalHash) {'backup + replace / копия + замена'} else {'create / создать'}}}
    Write-Output "Plan only; game unchanged. Files: $($plan.Count) / Только план; игра не изменена. Файлов: $($plan.Count)"
    return
  }
}

AssertClosed
[IO.Directory]::CreateDirectory($stateRoot) | Out-Null
$installerLock = [IO.File]::Open((Join-Path $stateRoot 'installer.lock'), [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
  if ($Action -eq 'Uninstall') {
    $state = Get-Content -LiteralPath $activeFile -Raw | ConvertFrom-Json
    Restore $state
    Write-Output 'Removed; original files restored. Backups kept / Удалено; исходные файлы восстановлены. Копии сохранены'
    return
  }
  if (Test-Path -LiteralPath $activeFile) { throw 'Another installation appeared / Обнаружена другая установка' }
  $backupRoot = Join-Path $stateRoot ([guid]::NewGuid().ToString('N'))
  [IO.Directory]::CreateDirectory($backupRoot) | Out-Null
  foreach ($entry in $plan) {
    if ((Hash (Target $entry.relative)) -ne $entry.originalHash) { throw 'Destination changed while preparing / Файл изменился во время подготовки' }
    if ($entry.originalHash) {
      $entry.backup = Join-Path $backupRoot $entry.relative
      [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($entry.backup)) | Out-Null
      Copy-Item -LiteralPath (Target $entry.relative) -Destination $entry.backup
      if ((Hash $entry.backup) -ne $entry.originalHash) { throw 'Backup verification failed / Ошибка проверки копии' }
    }
  }
  $state = [pscustomobject]@{version=1;gamePath=$targetRoot;backupRoot=$backupRoot;status='prepared';entries=@($plan)}
  SaveState $state
  try {
    foreach ($entry in $plan) {
      AssertClosed
      $dest = Target $entry.relative
      if ((Hash $dest) -ne $entry.originalHash) { throw 'Destination changed before copy / Файл изменился перед копированием' }
      [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dest)) | Out-Null
      Copy-Item -LiteralPath $entry.source -Destination $dest -Force
      if ((Hash $dest) -ne $entry.installedHash) { throw 'Installed file verification failed / Ошибка проверки установленного файла' }
    }
    $state.status = 'installed'
    SaveState $state
  } catch {
    $installError = $_
    try { Restore $state } catch { Write-Warning "Rollback needs attention; active.json retained / Требуется восстановление; active.json сохранён: $_" }
    throw $installError
  }
  Write-Output "Installed $($plan.Count) files; game was not launched / Установлено $($plan.Count) файлов; игра не запускалась"
} finally { $installerLock.Dispose() }
