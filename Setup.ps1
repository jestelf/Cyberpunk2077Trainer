param(
  [ValidateSet('Plan','Install','Uninstall')][string]$Action = 'Install',
  [string]$GamePath = ''
)
$ErrorActionPreference = 'Stop'
try {
  if ($Action -ne 'Plan' -and (Get-Process -Name Cyberpunk2077Trainer -ErrorAction SilentlyContinue)) {
    throw 'Close the trainer first / Сначала закройте трейнер'
  }
  if (-not $GamePath) {
    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object System.Windows.Forms.FolderBrowserDialog
    $picker.Description = 'Select Cyberpunk 2077 folder (contains bin, r6) / Выберите папку Cyberpunk 2077 (внутри bin, r6)'
    $picker.ShowNewFolderButton = $false
    try {
      if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Output 'Cancelled; no changes / Отменено; изменений нет'
        exit 0
      }
      $GamePath = $picker.SelectedPath
    } finally { $picker.Dispose() }
  }
  if ($Action -ne 'Uninstall') {
    $packageRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
    foreach ($line in Get-Content -LiteralPath (Join-Path $packageRoot 'SHA256SUMS.txt')) {
      if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw 'Invalid package manifest / Повреждён список файлов' }
      $expected = $matches[1]
      $relative = $matches[2]
      $file = [IO.Path]::GetFullPath((Join-Path $packageRoot $relative))
      if (-not $file.StartsWith($packageRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Invalid package path / Неверный путь в пакете'
      }
      if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
          (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
        throw "Package file missing or damaged / Файл отсутствует или повреждён: $relative"
      }
    }
  }
  & (Join-Path $PSScriptRoot 'Install.ps1') -Action $Action -GamePath $GamePath -IncludeDependencies
  if ($Action -eq 'Install') {
    Write-Output 'Ready. Start the game, load a save, then open Cyberpunk2077Trainer.exe.'
    Write-Output 'Готово. Запустите игру, загрузите сохранение, затем откройте Cyberpunk2077Trainer.exe.'
  }
} catch {
  Write-Output ('ERROR / ОШИБКА: ' + $_.Exception.Message)
  exit 1
}
