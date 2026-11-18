param(
  [ValidateSet('Debug', 'Profile')]
  [string] $BuildMode = 'Profile',
  [switch] $NoLaunch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-NormalizedPath {
  param([Parameter(Mandatory = $true)][string] $Path)

  return [IO.Path]::GetFullPath($Path).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
  )
}

function Test-PathInside {
  param(
    [Parameter(Mandatory = $true)][string] $Candidate,
    [Parameter(Mandatory = $true)][string] $Root
  )

  $normalizedCandidate = Get-NormalizedPath $Candidate
  $normalizedRoot = Get-NormalizedPath $Root
  $prefix = $normalizedRoot + [IO.Path]::DirectorySeparatorChar
  return $normalizedCandidate.StartsWith(
    $prefix,
    [StringComparison]::OrdinalIgnoreCase
  )
}

function Assert-ExactPath {
  param(
    [Parameter(Mandatory = $true)][string] $Actual,
    [Parameter(Mandatory = $true)][string] $Expected,
    [Parameter(Mandatory = $true)][string] $Label
  )

  if (-not [string]::Equals(
      (Get-NormalizedPath $Actual),
      (Get-NormalizedPath $Expected),
      [StringComparison]::OrdinalIgnoreCase
    )) {
    throw "$Label resolved outside its expected path: $Actual"
  }
}

function Assert-PlainDirectory {
  param([Parameter(Mandatory = $true)][string] $Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }
  $item = Get-Item -LiteralPath $Path -Force
  if (-not $item.PSIsContainer) {
    throw "Expected a directory: $Path"
  }
  if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
    throw "Refusing to use a reparse-point directory: $Path"
  }
}

if ([string]::IsNullOrWhiteSpace($env:LOCALAPPDATA) -or
    [string]::IsNullOrWhiteSpace($env:APPDATA)) {
  throw 'LOCALAPPDATA and APPDATA must be available.'
}

$projectRoot = Get-NormalizedPath (Join-Path $PSScriptRoot '..')
$flutterWrapper = Join-Path $projectRoot 'tool\flutter.ps1'
$buildModeName = switch ($BuildMode.ToLowerInvariant()) {
  'debug' { 'Debug' }
  'profile' { 'Profile' }
  default { throw "Unsupported Windows test build mode: $BuildMode" }
}
$buildModeFlag = "--$($buildModeName.ToLowerInvariant())"
$sourceBundle = Join-Path $projectRoot (
  "build\windows\x64\runner\$buildModeName"
)
$sourceExe = Join-Path $sourceBundle 'DailyCalendar.exe'

$programsRoot = Get-NormalizedPath (Join-Path $env:LOCALAPPDATA 'Programs')
$installRoot = Get-NormalizedPath (
  Join-Path $programsRoot 'DailyCalendar Test'
)
$stagingRoot = Get-NormalizedPath (
  Join-Path $programsRoot '.DailyCalendar Test.staging'
)
$backupRoot = Get-NormalizedPath (
  Join-Path $programsRoot '.DailyCalendar Test.backup'
)
$targetExe = Join-Path $installRoot 'DailyCalendar Test.exe'
# installer.iss installs the production app to {autopf}\DailyCalendar.
$productionRoot = Get-NormalizedPath (Join-Path $env:ProgramFiles 'DailyCalendar')
$productionExe = Join-Path $productionRoot 'DailyCalendar.exe'
$shortcutPath = Get-NormalizedPath (
  Join-Path $env:APPDATA (
    'Microsoft\Windows\Start Menu\Programs\DailyCalendar Test.lnk'
  )
)

Assert-ExactPath $installRoot (Join-Path $programsRoot 'DailyCalendar Test') `
  'Test install root'
Assert-ExactPath $stagingRoot `
  (Join-Path $programsRoot '.DailyCalendar Test.staging') 'Staging root'
Assert-ExactPath $backupRoot `
  (Join-Path $programsRoot '.DailyCalendar Test.backup') 'Backup root'

foreach ($candidate in @($installRoot, $stagingRoot, $backupRoot, $targetExe)) {
  if ([string]::Equals(
      (Get-NormalizedPath $candidate),
      $productionRoot,
      [StringComparison]::OrdinalIgnoreCase
    ) -or (Test-PathInside $candidate $productionRoot)) {
    throw "Refusing to target the production installation: $candidate"
  }
  if (-not (Test-PathInside $candidate $programsRoot)) {
    throw "Test target is outside the current user's Programs directory: $candidate"
  }
}

foreach ($directory in @($installRoot, $stagingRoot, $backupRoot)) {
  Assert-PlainDirectory $directory
}

$productionHashBefore = if (Test-Path -LiteralPath $productionExe) {
  (Get-FileHash -LiteralPath $productionExe -Algorithm SHA256).Hash
} else {
  $null
}

if (-not (Test-Path -LiteralPath $flutterWrapper -PathType Leaf)) {
  throw "Flutter wrapper not found: $flutterWrapper"
}

$buildArgs = @('build', 'windows', $buildModeFlag, '--no-pub')
& $flutterWrapper -FlutterArgs $buildArgs
if ($LASTEXITCODE -ne 0) {
  throw "Windows $buildModeName build failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath $sourceExe -PathType Leaf)) {
  throw "$buildModeName executable not found: $sourceExe"
}
$sourceVersion = (Get-Item -LiteralPath $sourceExe).VersionInfo
foreach ($field in @('ProductName', 'FileDescription', 'InternalName')) {
  if ($sourceVersion.$field -ne 'DailyCalendar Test') {
    throw (
      "$buildModeName executable has an unsafe $field value: " +
      $sourceVersion.$field
    )
  }
}
if ($buildModeName -eq 'Profile') {
  $profileAotLibrary = Join-Path $sourceBundle 'data\app.so'
  $profileKernelBlob = Join-Path (
    $sourceBundle
  ) 'data\flutter_assets\kernel_blob.bin'
  if (-not (Test-Path -LiteralPath $profileAotLibrary -PathType Leaf)) {
    throw "Profile AOT library not found: $profileAotLibrary"
  }
  if (Test-Path -LiteralPath $profileKernelBlob -PathType Leaf) {
    throw "Profile bundle contains a Debug kernel blob: $profileKernelBlob"
  }
  if ($sourceVersion.IsDebug -ne $false) {
    throw 'Profile executable is marked as a Debug binary.'
  }
}

$runningTest = Get-CimInstance Win32_Process -ErrorAction Stop |
  Where-Object {
    -not [string]::IsNullOrWhiteSpace($_.ExecutablePath) -and
    (Test-PathInside $_.ExecutablePath $installRoot)
  } |
  Select-Object -First 1
if ($null -ne $runningTest) {
  throw "Close DailyCalendar Test before updating it (PID $($runningTest.ProcessId))."
}

if (Test-Path -LiteralPath $stagingRoot) {
  Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}
if (Test-Path -LiteralPath $backupRoot) {
  Remove-Item -LiteralPath $backupRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingRoot | Out-Null

Get-ChildItem -LiteralPath $sourceBundle -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $stagingRoot -Recurse -Force
}
$stagedSourceExe = Join-Path $stagingRoot 'DailyCalendar.exe'
$stagedTargetExe = Join-Path $stagingRoot 'DailyCalendar Test.exe'
if (-not (Test-Path -LiteralPath $stagedSourceExe -PathType Leaf)) {
  throw "Staged executable not found: $stagedSourceExe"
}
Move-Item -LiteralPath $stagedSourceExe -Destination $stagedTargetExe

$hadPreviousInstall = Test-Path -LiteralPath $installRoot
$previousMoved = $false
$newInstalled = $false
try {
  if ($hadPreviousInstall) {
    Move-Item -LiteralPath $installRoot -Destination $backupRoot
    $previousMoved = $true
  }
  Move-Item -LiteralPath $stagingRoot -Destination $installRoot
  $newInstalled = $true

  if (-not (Test-Path -LiteralPath $targetExe -PathType Leaf)) {
    throw "Installed test executable not found: $targetExe"
  }

  $shortcutDirectory = Split-Path -Parent $shortcutPath
  New-Item -ItemType Directory -Force -Path $shortcutDirectory | Out-Null
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = $targetExe
  $shortcut.WorkingDirectory = $installRoot
  $shortcut.IconLocation = "$targetExe,0"
  $shortcut.Description = "DailyCalendar Test ($buildModeName)"
  $shortcut.Save()

  if (Test-Path -LiteralPath $backupRoot) {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force
  }
} catch {
  # Remove only what this run installed. When the backup move itself failed,
  # $installRoot is still the previous test app and must stay as it is.
  if ($newInstalled -and (Test-Path -LiteralPath $installRoot)) {
    Assert-ExactPath $installRoot `
      (Join-Path $programsRoot 'DailyCalendar Test') 'Rollback install root'
    Remove-Item -LiteralPath $installRoot -Recurse -Force
  }
  if ($previousMoved -and (Test-Path -LiteralPath $backupRoot) -and
      -not (Test-Path -LiteralPath $installRoot)) {
    Move-Item -LiteralPath $backupRoot -Destination $installRoot
  }
  throw
} finally {
  if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
  }
}

if ($null -ne $productionHashBefore) {
  $productionHashAfter = (
    Get-FileHash -LiteralPath $productionExe -Algorithm SHA256
  ).Hash
  if ($productionHashAfter -ne $productionHashBefore) {
    throw 'Production DailyCalendar.exe changed during the test installation.'
  }
}

Write-Host "DailyCalendar Test ($buildModeName) installed at: $installRoot"
Write-Host "Shortcut created at: $shortcutPath"

if (-not $NoLaunch) {
  Start-Process -FilePath $targetExe -WorkingDirectory $installRoot
}
