param(
    [Parameter(Mandatory = $true)]
    [string]$ApiBaseUrl
)

$ErrorActionPreference = "Stop"

function Test-PrivateOrLocalHost {
    param([string]$HostName)

    $hostValue = $HostName.Trim().ToLowerInvariant()

    if (
        $hostValue -eq "localhost" -or
        $hostValue -eq "127.0.0.1" -or
        $hostValue -eq "0.0.0.0" -or
        $hostValue -eq "::1" -or
        $hostValue.EndsWith(".local")
    ) {
        return $true
    }

    if ($hostValue -match "^10\.") {
        return $true
    }

    if ($hostValue -match "^192\.168\.") {
        return $true
    }

    if ($hostValue -match "^172\.(1[6-9]|2[0-9]|3[0-1])\.") {
        return $true
    }

    return $false
}

$flutterRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $flutterRoot

if (-not (Test-Path -LiteralPath ".\pubspec.yaml")) {
    throw "pubspec.yaml was not found in $flutterRoot"
}

$normalizedApiUrl = $ApiBaseUrl.Trim().TrimEnd("/")

$uri = $null
if (-not [Uri]::TryCreate(
    $normalizedApiUrl,
    [UriKind]::Absolute,
    [ref]$uri
)) {
    throw "API_BASE_URL must be an absolute HTTPS URL."
}

if ($uri.Scheme -ne "https") {
    throw "Production TabangNow APK builds require HTTPS. Received: $($uri.Scheme)"
}

if (Test-PrivateOrLocalHost -HostName $uri.Host) {
    throw "Production APK cannot target localhost/private-network host: $($uri.Host)"
}

if ($uri.Port -ne 443 -or
    $uri.UserInfo -or
    ($uri.AbsolutePath -ne "/" -and $uri.AbsolutePath -ne "") -or
    $uri.Query -or
    $uri.Fragment) {
    throw "Production API_BASE_URL must be the bare HTTPS origin, without credentials, paths, queries, fragments, or a custom port."
}

if ($normalizedApiUrl -match "/api(/|$)" -or $normalizedApiUrl -match "/api/v1") {
    throw @"
Pass the Laravel ROOT URL, not /api or /api/v1.
Example:
https://tabangnow.example.com
"@
}

$keyPropertiesPath = Join-Path $flutterRoot "android\key.properties"

if (-not (Test-Path -LiteralPath $keyPropertiesPath)) {
    throw @"
Production signing is not configured.

Run:
powershell -ExecutionPolicy Bypass -File .\tool\create_android_release_keystore.ps1
"@
}

$keyProperties = @{}

Get-Content -LiteralPath $keyPropertiesPath | ForEach-Object {
    $line = $_.Trim()

    if (
        $line.Length -gt 0 -and
        -not $line.StartsWith("#") -and
        $line.Contains("=")
    ) {
        $parts = $line.Split("=", 2)
        $keyProperties[$parts[0].Trim()] = $parts[1].Trim()
    }
}

foreach ($requiredKey in @(
    "storePassword",
    "keyPassword",
    "keyAlias",
    "storeFile"
)) {
    if (
        -not $keyProperties.ContainsKey($requiredKey) -or
        [string]::IsNullOrWhiteSpace($keyProperties[$requiredKey])
    ) {
        throw "android/key.properties is missing required value: $requiredKey"
    }
}

$storeFileValue = $keyProperties["storeFile"].Replace("\\", "\")

if ([IO.Path]::IsPathRooted($storeFileValue)) {
    $storeFilePath = $storeFileValue
}
else {
    $storeFilePath = Join-Path `
        (Join-Path $flutterRoot "android\app") `
        $storeFileValue
}

$storeFilePath = [IO.Path]::GetFullPath($storeFilePath)

if (-not (Test-Path -LiteralPath $storeFilePath)) {
    throw "Release keystore file does not exist: $storeFilePath"
}

Write-Host ""
Write-Host "TabangNow Production APK Build" -ForegroundColor Cyan
Write-Host "------------------------------" -ForegroundColor Cyan
Write-Host "API: $normalizedApiUrl" -ForegroundColor Green
Write-Host ""

Write-Host "[1/5] flutter pub get" -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    throw "flutter pub get failed."
}

Write-Host "[2/5] flutter analyze" -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) {
    throw "flutter analyze failed."
}

Write-Host "[3/5] flutter test" -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) {
    throw "flutter test failed."
}

Write-Host "[4/5] Building signed release APK" -ForegroundColor Yellow

# Gradle reads ORG_GRADLE_PROJECT_* environment variables as project
# properties. This supplies the verified HTTPS host to AndroidManifest.xml.
# Restore the caller's environment even if the build fails.
$resetHostEnvironmentName = "ORG_GRADLE_PROJECT_TABANGNOW_RESET_HOST"
$previousResetHost = [Environment]::GetEnvironmentVariable(
    $resetHostEnvironmentName, "Process"
)
try {
    [Environment]::SetEnvironmentVariable(
        $resetHostEnvironmentName, $uri.Host, "Process"
    )
    flutter build apk `
        --release `
        "--dart-define=API_BASE_URL=$normalizedApiUrl"
    if ($LASTEXITCODE -ne 0) {
        throw "flutter build apk --release failed."
    }
}
finally {
    [Environment]::SetEnvironmentVariable(
        $resetHostEnvironmentName, $previousResetHost, "Process"
    )
}

$builtApk = Join-Path `
    $flutterRoot `
    "build\app\outputs\flutter-apk\app-release.apk"

if (-not (Test-Path -LiteralPath $builtApk)) {
    throw "Expected release APK was not produced: $builtApk"
}

Write-Host "[5/5] Verifying APK signature" -ForegroundColor Yellow

$sdkRoot = if ($env:ANDROID_HOME) {
    $env:ANDROID_HOME
}
elseif ($env:ANDROID_SDK_ROOT) {
    $env:ANDROID_SDK_ROOT
}
else {
    Join-Path $env:LOCALAPPDATA "Android\Sdk"
}

$buildToolsRoot = Join-Path $sdkRoot "build-tools"

if (-not (Test-Path -LiteralPath $buildToolsRoot)) {
    throw "Android SDK build-tools directory was not found: $buildToolsRoot"
}

$apksigner = Get-ChildItem `
    -LiteralPath $buildToolsRoot `
    -Directory |
    Sort-Object Name -Descending |
    ForEach-Object {
        $candidate = Join-Path $_.FullName "apksigner.bat"
        if (Test-Path -LiteralPath $candidate) {
            $candidate
        }
    } |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($apksigner)) {
    throw "apksigner.bat was not found in Android SDK build-tools."
}

& $apksigner verify --verbose --print-certs $builtApk

if ($LASTEXITCODE -ne 0) {
    throw "APK signature verification failed."
}

# Fail closed if the final APK does not actually claim the TabangNow
# production password-reset host in its compiled Android manifest.
$aapt = Join-Path (Split-Path -Parent $apksigner) "aapt.exe"
if (-not (Test-Path -LiteralPath $aapt)) {
    throw "aapt.exe is required to verify the release App Link host."
}
$manifestText = (& $aapt dump xmltree $builtApk AndroidManifest.xml 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the built APK Android manifest."
}
$hostLine = @($manifestText -split '\r?\n' | Where-Object {
    $_ -match 'android:host' -and $_ -match [Regex]::Escape($uri.Host)
})
if ($hostLine.Count -eq 0) {
    throw "APK reset-link host does not match production API host: $($uri.Host)"
}
Write-Host "Verified APK App Link host: $($uri.Host)" -ForegroundColor Green

# TABANGNOW_ORIGINAL_SOUND_RELEASE_GATE
# Android release optimization may rename res/raw paths; verify uncompressed
# audio bytes against the four existing original sources. Fail before distribution.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$originalAudio = @(
    'tabangnow_notification_v4.mp3',
    'tabangnow_moderate_v1.mp3',
    'tabangnow_low_v1.mp3',
    'tabangnow_notification.wav'
)
$audioZip = $null
try {
    $audioZip = [System.IO.Compression.ZipFile]::OpenRead($builtApk)
    $audioEntries = @($audioZip.Entries | Where-Object { $_.FullName -match '(?i)^res/.*\.(mp3|wav|ogg)$' })
    $packagedAudio = @()
    foreach ($entry in $audioEntries) {
        $stream = $null
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $stream = $entry.Open()
            $bytes = $sha.ComputeHash($stream)
            $hex = ([BitConverter]::ToString($bytes) -replace '-', '')
            $packagedAudio += [pscustomobject]@{ Hash=$hex; Name=$entry.FullName; Bytes=$entry.Length }
        }
        finally {
            if ($null -ne $stream) { $stream.Dispose() }
            $sha.Dispose()
        }
    }
    foreach ($sound in $originalAudio) {
        $source = Join-Path $flutterRoot ("android\app\src\main\res\raw\" + $sound)
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "RELEASE BLOCKED: missing source $sound" }
        $expected = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        $expectedSize = (Get-Item -LiteralPath $source).Length
        $hit = @($packagedAudio | Where-Object { $_.Hash -eq $expected -and $_.Bytes -eq $expectedSize })
        if ($hit.Count -ne 1) { throw "RELEASE BLOCKED: original $sound not included byte-identically in APK." }
        Write-Host "Packaged original: $sound -> $($hit[0].Name)" -ForegroundColor Green
    }
}
finally {
    if ($null -ne $audioZip) { $audioZip.Dispose() }
}

$distDir = Join-Path $flutterRoot "dist"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$distApk = Join-Path $distDir "TabangNow.apk"
Copy-Item -LiteralPath $builtApk -Destination $distApk -Force

$hash = Get-FileHash -Algorithm SHA256 -LiteralPath $distApk

Write-Host ""
Write-Host "SUCCESS: Signed TabangNow production APK created." -ForegroundColor Green
Write-Host "APK:    $distApk" -ForegroundColor Green
Write-Host "SHA256: $($hash.Hash)" -ForegroundColor Green
Write-Host ""
Write-Host "This APK targets:" -ForegroundColor Cyan
Write-Host $normalizedApiUrl
