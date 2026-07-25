param(
    [string]$ExpectedSha1 = "B6:0A:53:2C:27:11:18:96:28:94:75:62:56:B1:A2:5A:BA:14:1A:C2",
    [string]$Keystore,
    [string]$Alias = "upload",
    [string]$Bundle,
    [switch]$PromptForPassword
)

$ErrorActionPreference = "Stop"

function Normalize-Sha1([string]$value) {
    return ($value -replace "[^A-Fa-f0-9]", "").ToUpperInvariant()
}

function Get-Sha1FromOutput([string[]]$lines) {
    $match = $lines | Select-String -Pattern "SHA1:\s*([A-Fa-f0-9:]+)" | Select-Object -First 1
    if (-not $match) {
        throw "Could not find a SHA1 fingerprint in keytool output."
    }

    return $match.Matches[0].Groups[1].Value
}

if (-not $Keystore -and -not $Bundle) {
    $Keystore = "android/upload-keystore.jks"
}

if ($Keystore -and $Bundle) {
    throw "Pass either -Keystore or -Bundle, not both."
}

if ($Keystore) {
    if (-not (Test-Path -LiteralPath $Keystore)) {
        throw "Keystore not found: $Keystore"
    }

    $args = @("-list", "-v", "-keystore", $Keystore, "-alias", $Alias)
    if ($PromptForPassword) {
        $storePassword = Read-Host "Keystore password" -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword)
        try {
            $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
            $args += @("-storepass", $plainPassword)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    $output = & keytool @args 2>&1
} else {
    if (-not (Test-Path -LiteralPath $Bundle)) {
        throw "Bundle not found: $Bundle"
    }

    $output = & keytool -printcert -jarfile $Bundle 2>&1
}

if ($LASTEXITCODE -ne 0) {
    $output | Write-Output
    exit $LASTEXITCODE
}

$actualSha1 = Get-Sha1FromOutput $output
$expectedNormalized = Normalize-Sha1 $ExpectedSha1
$actualNormalized = Normalize-Sha1 $actualSha1

Write-Output "Expected SHA1: $ExpectedSha1"
Write-Output "Actual SHA1:   $actualSha1"

if ($actualNormalized -eq $expectedNormalized) {
    Write-Output "OK: signing certificate matches Play Console."
    exit 0
}

Write-Error "Mismatch: this artifact is signed with the wrong certificate."
exit 1
