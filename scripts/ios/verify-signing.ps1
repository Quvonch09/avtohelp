# Verification script for local iOS signing assets on Windows
# Part of Avtohelp CI/CD Pipeline

$signingDir = "C:\ios-signing"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "iOS Signing Assets Verification" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$allOk = $true

# Check directory
if (!(Test-Path $signingDir)) {
    Write-Host "[-] C:\ios-signing directory does not exist. Run prepare-signing.ps1 first." -ForegroundColor Red
    $allOk = $false
} else {
    # Check .p12
    $p12Files = Get-ChildItem -Path $signingDir -Filter *.p12 -ErrorAction SilentlyContinue
    if (!$p12Files -or $p12Files.Count -eq 0) {
        Write-Host "[-] Missing: Certificate file (.p12) in $signingDir" -ForegroundColor Red
        $allOk = $false
    } else {
        Write-Host "[+] Found: $($p12Files.Count) certificate file(s) (.p12)" -ForegroundColor Green
    }

    # Check .mobileprovision
    $provisionFiles = Get-ChildItem -Path $signingDir -Filter *.mobileprovision -ErrorAction SilentlyContinue
    if (!$provisionFiles -or $provisionFiles.Count -eq 0) {
        Write-Host "[-] Missing: Provisioning profile (.mobileprovision) in $signingDir" -ForegroundColor Red
        $allOk = $false
    } else {
        Write-Host "[+] Found: $($provisionFiles.Count) provisioning profile(s) (.mobileprovision)" -ForegroundColor Green
    }

    # Check Base64 generated txts
    $p12Txts = Get-ChildItem -Path $signingDir -Filter *p12_base64.txt -ErrorAction SilentlyContinue
    $provisionTxts = Get-ChildItem -Path $signingDir -Filter *mobileprovision_base64.txt -ErrorAction SilentlyContinue

    if (!$p12Txts -or $p12Txts.Count -eq 0) {
        Write-Host "[-] Missing: Encoded P12 text file (*_p12_base64.txt) - Run encode-secrets.ps1" -ForegroundColor Yellow
    } else {
        Write-Host "[+] Found: Encoded P12 text file" -ForegroundColor Green
    }

    if (!$provisionTxts -or $provisionTxts.Count -eq 0) {
        Write-Host "[-] Missing: Encoded Provisioning Profile text file (*_mobileprovision_base64.txt) - Run encode-secrets.ps1" -ForegroundColor Yellow
    } else {
        Write-Host "[+] Found: Encoded Provisioning Profile text file" -ForegroundColor Green
    }
}

if ($allOk) {
    Write-Host "`n[SUCCESS] Local verification complete. Ready for GitHub Secrets configuration!" -ForegroundColor Green
} else {
    Write-Host "`n[WARNING] Some assets are missing. Please complete setup in Apple Developer and local folder." -ForegroundColor Yellow
}
