$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$googleServicesPath = Join-Path $projectRoot 'android\app\google-services.json'
$debugKeystore = Join-Path $env:USERPROFILE '.android\debug.keystore'

if (-not (Test-Path $googleServicesPath)) {
  Write-Error "Khong tim thay file: $googleServicesPath"
}

if (-not (Test-Path $debugKeystore)) {
  Write-Error "Khong tim thay debug.keystore: $debugKeystore"
}

Write-Host 'Doc SHA-1 tu debug keystore...'
$keytoolOutput = & keytool -list -v -alias androiddebugkey -keystore $debugKeystore -storepass android -keypass android
$sha1Line = $keytoolOutput | Select-String -Pattern 'SHA1:' | Select-Object -First 1

if (-not $sha1Line) {
  Write-Error 'Khong trich duoc SHA1 tu keytool.'
}

$debugSha1 = ($sha1Line.ToString().Split(':', 2)[1]).Trim().ToLower()
# Normalize: remove colons and whitespace so it matches firebase `certificate_hash` format
$debugSha1 = $debugSha1 -replace '[:\s]', ''

Write-Host 'Doc certificate_hash trong google-services.json...'
$json = Get-Content $googleServicesPath -Raw | ConvertFrom-Json
$firebaseSha1 = $null

foreach ($client in $json.client) {
  if ($client.oauth_client) {
    foreach ($oauth in $client.oauth_client) {
      if ($oauth.android_info -and $oauth.android_info.certificate_hash) {
        $firebaseSha1 = $oauth.android_info.certificate_hash.ToLower()
        # Normalize firebase hash too (defensive): remove any colons or whitespace
        $firebaseSha1 = $firebaseSha1 -replace '[:\s]', ''
        break
      }
    }
  }
  if ($firebaseSha1) { break }
}

if (-not $firebaseSha1) {
  Write-Error 'Khong tim thay certificate_hash trong google-services.json.'
}

Write-Host "SHA1 debug keystore : $debugSha1"
Write-Host "SHA1 firebase config: $firebaseSha1"

if ($debugSha1 -eq $firebaseSha1) {
  Write-Host 'KET QUA: SHA-1 da khop. Co the dang nhap Google tren Android.' -ForegroundColor Green
  exit 0
}

Write-Host 'KET QUA: SHA-1 CHUA KHOP.' -ForegroundColor Yellow
Write-Host 'Ban can vao Firebase Console -> Project settings -> Android app -> Add fingerprint, them SHA-1 debug, sau do tai lai google-services.json.'
exit 2
