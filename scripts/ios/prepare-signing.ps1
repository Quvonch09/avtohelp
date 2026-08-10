# Prepare iOS Signing Directory and Environment on Windows
# Part of Avtohelp CI/CD Pipeline

$signingDir = "C:\ios-signing"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "iOS Signing Setup Preparation for Windows" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Create secure local directory
if (!(Test-Path $signingDir)) {
    New-Item -ItemType Directory -Path $signingDir | Out-Null
    Write-Host "[+] Created local directory: $signingDir" -ForegroundColor Green
} else {
    Write-Host "[*] Local directory already exists: $signingDir" -ForegroundColor Yellow
}

# 2. Check OpenSSL
$gitOpenSsl = "C:\Program Files\Git\usr\bin\openssl.exe"
$openSslCmd = "openssl"

if (Get-Command $openSslCmd -ErrorAction SilentlyContinue) {
    Write-Host "[+] OpenSSL is already available in your PATH." -ForegroundColor Green
} elseif (Test-Path $gitOpenSsl) {
    Write-Host "[+] OpenSSL found in Git installation: $gitOpenSsl" -ForegroundColor Green
    # Add alias/path helper instructions
    Write-Host "    You can run it using: & '$gitOpenSsl'" -ForegroundColor Yellow
} else {
    Write-Host "[-] OpenSSL not found in PATH or Git installation." -ForegroundColor Red
    Write-Host "    Please install OpenSSL using Chocolatey (choco install openssl) or" -ForegroundColor Yellow
    Write-Host "    download from slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
}

Write-Host "`nReady! All temporary certificates/profiles should be placed in $signingDir" -ForegroundColor Green
Write-Host "Ensure you NEVER commit anything inside $signingDir to GitHub." -ForegroundColor Yellow
