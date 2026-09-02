param(
    [Parameter(Mandatory = $true)]
    [string]$PatchPath,
    [string]$Notes = "ARKhives stable update.",
    [ValidateSet("stable", "preview")]
    [string]$Channel = "stable",
    [string]$Repository = "Kennzyy05/arkhives-updates"
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $PatchPath -PathType Leaf)) {
    Fail "Patch file not found: $PatchPath"
}

$PatchPath = (Resolve-Path -LiteralPath $PatchPath).Path
$FileName = [System.IO.Path]::GetFileName($PatchPath)

if (-not $FileName.EndsWith(".arkenpatch", [System.StringComparison]::OrdinalIgnoreCase)) {
    Fail "Only a signed .arkenpatch file may be published."
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "GitHub CLI (gh) is not installed. Install it once, then run: gh auth login"
}

& gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "GitHub CLI is not authenticated. Run: gh auth login"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = $null
try {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($PatchPath)
    $manifestEntry = $zip.GetEntry("manifest.json")
    $sigEntry = $zip.GetEntry("signature.ed25519")
    $appEntry = $zip.GetEntry("app.exe")

    if ($null -eq $manifestEntry -or $null -eq $sigEntry -or $null -eq $appEntry) {
        Fail "Patch is missing manifest.json, signature.ed25519, or app.exe."
    }

    $reader = New-Object System.IO.StreamReader($manifestEntry.Open())
    try {
        $manifestText = $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }

    $manifest = $manifestText | ConvertFrom-Json
}
finally {
    if ($null -ne $zip) { $zip.Dispose() }
}

$Version = [string]$manifest.version
$MinimumVersion = [string]$manifest.min_version
$Architecture = [string]$manifest.arch

if ([string]::IsNullOrWhiteSpace($Version)) { Fail "manifest.json has no version." }
if ([string]::IsNullOrWhiteSpace($MinimumVersion)) { Fail "manifest.json has no min_version." }
if ($Architecture -ne "amd64") { Fail "Expected amd64 patch, got '$Architecture'." }

$Tag = "v$Version"
$Sha256 = (Get-FileHash -LiteralPath $PatchPath -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host ""
Write-Host "ARKhives Publish Check" -ForegroundColor Cyan
Write-Host "  Patch:        $FileName"
Write-Host "  Version:      $Version"
Write-Host "  Minimum:      $MinimumVersion"
Write-Host "  Architecture: $Architecture"
Write-Host "  SHA-256:      $Sha256"
Write-Host "  Channel:      $Channel"
Write-Host ""

& gh release view $Tag --repo $Repository *> $null
if ($LASTEXITCODE -eq 0) {
    Fail "Release $Tag already exists. Refusing to replace an existing release automatically."
}

$ReleaseTitle = "ARKhives $Tag"
Write-Host "Creating GitHub Release $Tag and uploading the signed patch..." -ForegroundColor Yellow

$releaseArgs = @(
    "release", "create", $Tag, $PatchPath,
    "--repo", $Repository,
    "--target", "main",
    "--title", $ReleaseTitle,
    "--notes", $Notes
)
& gh @releaseArgs

if ($LASTEXITCODE -ne 0) {
    Fail "GitHub Release creation/upload failed. Feed files were NOT changed."
}

$releaseJson = (& gh api "repos/$Repository/releases/tags/$Tag") | ConvertFrom-Json
$asset = $releaseJson.assets | Where-Object { $_.name -eq $FileName } | Select-Object -First 1

if ($null -eq $asset) {
    Fail "Release exists, but uploaded asset '$FileName' was not found. Feed files were NOT changed."
}

$GitHubDigest = [string]$asset.digest
if ($GitHubDigest -and $GitHubDigest.ToLowerInvariant() -ne ("sha256:" + $Sha256)) {
    Fail "GitHub asset digest does not match the local patch. Feed files were NOT changed."
}

$PatchUrl = [string]$asset.browser_download_url
$ReleasePage = [string]$releaseJson.html_url

$feed = [ordered]@{
    schema = 1
    channel = $Channel
    available = $true
    version = $Version
    minimum_version = $MinimumVersion
    architecture = $Architecture
    patch_url = $PatchUrl
    release_page = $ReleasePage
    sha256 = $Sha256
    notes = $Notes
}

$FeedJson = ($feed | ConvertTo-Json -Depth 5) + [Environment]::NewLine
$FeedBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($FeedJson))

function Update-RepoFile([string]$Path, [string]$Message) {
    $current = (& gh api "repos/$Repository/contents/$Path?ref=main") | ConvertFrom-Json
    if (-not $current.sha) {
        Fail "Could not read current SHA for $Path."
    }

    $apiArgs = @(
        "api",
        "--method", "PUT",
        "repos/$Repository/contents/$Path",
        "-f", "message=$Message",
        "-f", "content=$FeedBase64",
        "-f", "sha=$($current.sha)",
        "-f", "branch=main"
    )
    & gh @apiArgs *> $null

    if ($LASTEXITCODE -ne 0) {
        Fail "Release is published, but updating $Path failed. The previous feed remains active."
    }
}

if ($Channel -eq "stable") {
    Update-RepoFile "channels/stable.json" "Publish ARKhives $Tag stable channel"
    Update-RepoFile "latest.json" "Publish ARKhives $Tag latest feed"
}
else {
    Update-RepoFile "channels/preview.json" "Publish ARKhives $Tag preview channel"
}

Write-Host ""
Write-Host "SUCCESS" -ForegroundColor Green
Write-Host "  Release: $ReleasePage"
Write-Host "  Asset:   $PatchUrl"
Write-Host "  SHA-256: $Sha256"
Write-Host ""

if ($Channel -eq "stable") {
    Write-Host "latest.json and channels/stable.json now advertise $Version."
}
else {
    Write-Host "channels/preview.json now advertises $Version."
}

Write-Host "The private signing key was not read, uploaded, or sent to GitHub by this script."
