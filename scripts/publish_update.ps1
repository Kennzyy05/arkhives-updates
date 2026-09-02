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

function Invoke-Gh {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $oldPreference = $ErrorActionPreference
    $errFile = [System.IO.Path]::GetTempFileName()
    try {
        $ErrorActionPreference = "Continue"
        $output = & gh @Arguments 2> $errFile
        $exitCode = $LASTEXITCODE
        $stderr = ""
        if (Test-Path -LiteralPath $errFile) {
            $stderr = (Get-Content -LiteralPath $errFile -Raw -ErrorAction SilentlyContinue)
        }
    }
    finally {
        $ErrorActionPreference = $oldPreference
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output   = (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine)
        Error    = [string]$stderr
    }
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
    Fail "GitHub CLI (gh) is not installed or is not in PATH."
}

$auth = Invoke-Gh -Arguments @("auth", "status")
if ($auth.ExitCode -ne 0) {
    Fail ("GitHub CLI is not authenticated. Run: gh auth login" +
          $(if ($auth.Error) { [Environment]::NewLine + $auth.Error.Trim() } else { "" }))
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

# Look up the release directly through the GitHub API.
# If it already exists from a previous partial run, verify it and resume safely.
$releaseLookup = Invoke-Gh -Arguments @("api", "repos/$Repository/releases/tags/$Tag")
$releaseJson = $null

if ($releaseLookup.ExitCode -eq 0) {
    try {
        $releaseJson = $releaseLookup.Output | ConvertFrom-Json
    }
    catch {
        Fail "GitHub returned invalid metadata for existing release $Tag."
    }

    $existingAsset = $releaseJson.assets | Where-Object { $_.name -eq $FileName } | Select-Object -First 1
    if ($null -eq $existingAsset) {
        Fail "Release $Tag already exists, but it does not contain '$FileName'. Refusing to modify the release automatically."
    }

    $existingDigest = [string]$existingAsset.digest
    if ($existingDigest -and $existingDigest.ToLowerInvariant() -ne ("sha256:" + $Sha256)) {
        Fail "Release $Tag already exists, but its uploaded asset digest does not match this patch."
    }

    Write-Host "Release $Tag already exists with the matching patch - resuming feed publication." -ForegroundColor Green
}
else {
    $lookupMessage = ($releaseLookup.Error + [Environment]::NewLine + $releaseLookup.Output).Trim()
    if ($lookupMessage -and $lookupMessage -notmatch "(?i)not found|404") {
        Fail "Could not safely check whether $Tag exists: $lookupMessage"
    }

    Write-Host "Release $Tag does not exist yet - ready to create it." -ForegroundColor Green
    Write-Host "Creating GitHub Release $Tag and uploading the signed patch..." -ForegroundColor Yellow

    $create = Invoke-Gh -Arguments @(
        "release", "create", $Tag, $PatchPath,
        "--repo", $Repository,
        "--target", "main",
        "--title", "ARKhives $Tag",
        "--notes", $Notes
    )

    if ($create.ExitCode -ne 0) {
        $detail = ($create.Error + [Environment]::NewLine + $create.Output).Trim()
        Fail "GitHub Release creation/upload failed. Feed files were NOT changed.$([Environment]::NewLine)$detail"
    }

    $verifyRelease = Invoke-Gh -Arguments @("api", "repos/$Repository/releases/tags/$Tag")
    if ($verifyRelease.ExitCode -ne 0) {
        Fail "Release was created, but verification through GitHub API failed. Feed files were NOT changed."
    }

    try {
        $releaseJson = $verifyRelease.Output | ConvertFrom-Json
    }
    catch {
        Fail "GitHub returned invalid release metadata. Feed files were NOT changed."
    }
}

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
    # main is the repository default branch, so no ?ref=main query string is needed.
    # This avoids Windows gh/PowerShell endpoint parsing issues.
    $read = Invoke-Gh -Arguments @("api", "repos/$Repository/contents/$Path")
    if ($read.ExitCode -ne 0) {
        $detail = ($read.Error + [Environment]::NewLine + $read.Output).Trim()
        Fail "Could not read the current GitHub file $Path. Release is published, but the previous feed remains active.$([Environment]::NewLine)$detail"
    }

    try {
        $current = $read.Output | ConvertFrom-Json
    }
    catch {
        Fail "Could not parse GitHub metadata for $Path. Release is published, but the previous feed remains active."
    }

    if (-not $current.sha) {
        Fail "Could not read current SHA for $Path. Release is published, but the previous feed remains active."
    }

    # Make reruns idempotent: if the feed already has exactly the intended content,
    # do not attempt another GitHub commit.
    try {
        $currentBytes = [Convert]::FromBase64String(([string]$current.content -replace "\s", ""))
        $currentText = [Text.Encoding]::UTF8.GetString($currentBytes)
        if ($currentText -eq $FeedJson) {
            Write-Host "$Path is already current." -ForegroundColor Green
            return
        }
    }
    catch {
        # If decoding the existing file fails, continue with the normal safe update path.
    }

    $write = Invoke-Gh -Arguments @(
        "api",
        "--method", "PUT",
        "repos/$Repository/contents/$Path",
        "-f", "message=$Message",
        "-f", "content=$FeedBase64",
        "-f", "sha=$($current.sha)",
        "-f", "branch=main"
    )

    if ($write.ExitCode -ne 0) {
        $detail = ($write.Error + [Environment]::NewLine + $write.Output).Trim()
        Fail "Release is published, but updating $Path failed. The previous feed remains active.$([Environment]::NewLine)$detail"
    }

    Write-Host "$Path updated successfully." -ForegroundColor Green
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
