# update.ps1 - re-encrypt the presentation and publish it to GitHub Pages.
#
# Usage (from any PowerShell window):
#   powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\projects\mitchell-presentation\update.ps1"
#
# The script asks for the password every time. The password is never written to disk:
# it lives only in this process (as the STATICRYPT_PASSWORD environment variable) and
# is removed when the script finishes.
#
# Use the SAME password as before so that "remember me" keeps working (the salt in
# .staticrypt.json stays the same, so saved logins stay valid).

[CmdletBinding()]
param(
    # Encrypt and check only; do not commit or push.
    [switch]$NoPush
)

$ErrorActionPreference = 'Stop'

# --- settings ---------------------------------------------------------------
$SourcePath   = 'C:\Users\yaniv\Desktop\Master- first year\טיפול משפחתי\מטלת סיום\מיטשל_שתי_שקופיות_קלוד_V3.3.html'
$RepoDir      = $PSScriptRoot
$TemplatePath = Join-Path $RepoDir 'template\password_template.html'
$StaticryptVersion = '3.5.4'
# A phrase that appears only in the unencrypted presentation (stored as base64 so this
# script does not trip its own leak check).
$LeakPhrase = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('15TXqtep15XXp9eUINec15Ag15PXldei15vXqiDXntei16bXnteU'))
# ---------------------------------------------------------------------------

function Fail([string]$msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

function Test-NoLeak {
    $hits = Get-ChildItem -LiteralPath $RepoDir -Recurse -File -Force |
        Where-Object { $_.FullName -notlike (Join-Path $RepoDir '.git') + '\*' } |
        Where-Object { [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8).Contains($LeakPhrase) }
    if ($hits) {
        Fail ("Unencrypted content found in: " + (($hits | ForEach-Object { $_.Name }) -join ', ') + ". Nothing was committed.")
    }
    Write-Host "Leak check passed: the unencrypted text is not in any repo file." -ForegroundColor Green
}

if (-not (Test-Path -LiteralPath $SourcePath)) { Fail "Source file not found: $SourcePath" }
if (-not (Test-Path -LiteralPath $TemplatePath)) { Fail "Template not found: $TemplatePath" }
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { Fail "npx not found. Install Node.js: winget install OpenJS.NodeJS.LTS" }

# --- ask for the password (twice, to catch typos) ---------------------------
function Read-Plain([string]$prompt) {
    $secure = Read-Host -Prompt $prompt -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

$pw1 = Read-Plain 'Password'
$pw2 = Read-Plain 'Password again'
if ([string]::IsNullOrEmpty($pw1)) { Fail 'Empty password.' }
if ($pw1 -cne $pw2) { Fail 'The two passwords do not match. Nothing was changed.' }
Remove-Variable pw2

# --- copy the source to a temp folder outside the repo ----------------------
$tmpDir = Join-Path ([IO.Path]::GetTempPath()) ("mitchell-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir | Out-Null
$tmpInput = Join-Path $tmpDir 'index.html'
Copy-Item -LiteralPath $SourcePath -Destination $tmpInput

# --- encrypt ----------------------------------------------------------------
Push-Location $RepoDir
try {
    $env:STATICRYPT_PASSWORD = $pw1
    & npx --yes "staticrypt@$StaticryptVersion" $tmpInput `
        -d $RepoDir `
        --short `
        --remember 30 `
        -t $TemplatePath `
        --config '.staticrypt.json'
    if ($LASTEXITCODE -ne 0) { Fail "staticrypt failed (exit code $LASTEXITCODE)." }
}
finally {
    Remove-Item Env:\STATICRYPT_PASSWORD -ErrorAction SilentlyContinue
    Remove-Variable pw1 -ErrorAction SilentlyContinue
    Pop-Location
    Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}

$indexPath = Join-Path $RepoDir 'index.html'
$encrypted = [IO.File]::ReadAllText($indexPath, [Text.Encoding]::UTF8)
if (-not $encrypted.Contains('staticrypt')) { Fail 'index.html does not look like a StatiCrypt page.' }

Test-NoLeak

if ($NoPush) {
    Write-Host 'Encrypted index.html is ready (not committed, -NoPush).' -ForegroundColor Yellow
    exit 0
}

# --- commit and push --------------------------------------------------------
Push-Location $RepoDir
try {
    git add -A
    Test-NoLeak
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'No changes to publish.' -ForegroundColor Yellow
        exit 0
    }
    git commit -q -m ("Update presentation " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    if ($LASTEXITCODE -ne 0) { Fail 'git commit failed.' }
    git push -q origin main
    if ($LASTEXITCODE -ne 0) { Fail 'git push failed. Try: gh auth status, then gh auth setup-git.' }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Published. GitHub Pages usually shows the update within 1-3 minutes:' -ForegroundColor Green
Write-Host '  https://yanivlein.github.io/mitchell-presentation/'
