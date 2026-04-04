param(
  [Parameter(Mandatory = $true)]
  [string]$KeystorePath,

  [Parameter(Mandatory = $true)]
  [string]$Alias,

  [Parameter(Mandatory = $true)]
  [string]$StorePass,

  [string]$KeyPass
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $KeystorePath)) {
  Write-Host "Khong tim thay keystore: $KeystorePath" -ForegroundColor Red
  exit 1
}

if ([string]::IsNullOrWhiteSpace($KeyPass)) {
  $KeyPass = $StorePass
}

Write-Host "Lay SHA-1 tu release keystore..." -ForegroundColor Cyan

$keytoolOutput = keytool -list -v -keystore $KeystorePath -alias $Alias -storepass $StorePass -keypass $KeyPass 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host "Khong doc duoc keystore. Kiem tra duong dan/alias/mat khau." -ForegroundColor Red
  $keytoolOutput | Out-Host
  exit 1
}

$shaLine = $keytoolOutput | Select-String -Pattern 'SHA1:' | Select-Object -First 1
if (-not $shaLine) {
  Write-Host 'Khong tim thay SHA1 trong output keytool.' -ForegroundColor Red
  exit 1
}

$sha = ($shaLine.ToString() -replace '.*SHA1:\s*', '').Trim().ToLower() -replace ':', ''

Write-Host "Release SHA-1: $sha" -ForegroundColor Green
Write-Host 'Them SHA-1 nay vao Firebase Console > Project settings > Android app fingerprints.' -ForegroundColor Yellow
