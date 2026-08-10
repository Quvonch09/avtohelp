# Base64 Encoder for iOS Signing Secrets on Windows
# Part of Avtohelp CI/CD Pipeline

$signingDir = "C:\ios-signing"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "iOS Signing Base64 Encoder" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Find .p12 and .mobileprovision files in C:\ios-signing
$p12Files = Get-ChildItem -Path $signingDir -Filter *.p12 -ErrorAction SilentlyContinue
$provisionFiles = Get-ChildItem -Path $signingDir -Filter *.mobileprovision -ErrorAction SilentlyContinue

$encodedAny = $false

if (!$p12Files -or $p12Files.Count -eq 0) {
    Write-Host "[-] No .p12 certificate found in $signingDir." -ForegroundColor Red
    Write-Host "    Please place your exported certificate (e.g. distribution.p12) there." -ForegroundColor Yellow
} else {
    foreach ($file in $p12Files) {
        $outName = Join-Path $signingDir ($file.BaseName + "_p12_base64.txt")
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $base64 = [Convert]::ToBase64String($bytes)
        [System.IO.File]::WriteAllText($outName, $base64)
        Write-Host "[+] Encoded: $($file.Name) -> $($file.BaseName)_p12_base64.txt" -ForegroundColor Green
        $encodedAny = $true
    }
}

if (!$provisionFiles -or $provisionFiles.Count -eq 0) {
    Write-Host "`n[-] No .mobileprovision profile found in $signingDir." -ForegroundColor Red
    Write-Host "    Please place your downloaded Ad Hoc profile there." -ForegroundColor Yellow
} else {
    foreach ($file in $provisionFiles) {
        $outName = Join-Path $signingDir ($file.BaseName + "_mobileprovision_base64.txt")
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $base64 = [Convert]::ToBase64String($bytes)
        [System.IO.File]::WriteAllText($outName, $base64)
        Write-Host "[+] Encoded: $($file.Name) -> $($file.BaseName)_mobileprovision_base64.txt" -ForegroundColor Green
        $encodedAny = $true
    }
}

if ($encodedAny) {
    Write-Host "`nAll Base64 text files created successfully in $signingDir" -ForegroundColor Green
    Write-Host "Copy the contents of those text files (no line breaks) and add them to your GitHub Secrets." -ForegroundColor Yellow
}
