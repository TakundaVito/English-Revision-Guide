param(
    [switch]$AllowDirty,
    [switch]$SkipApk,
    [switch]$RequireProductionSigning,
    [string]$ConfigFile = "config.production.json"
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location -LiteralPath $projectRoot

$startedAt = (Get-Date).ToUniversalTime()
$results = [System.Collections.Generic.List[object]]::new()
$overall = "pass"
$failureMessage = $null
$flutterCommand = $null

function Invoke-VI26Command {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    Write-Host "`n[VI26] $Name" -ForegroundColor Cyan
    Write-Host "$Executable $($Arguments -join ' ')"
    $commandStarted = (Get-Date).ToUniversalTime()
    & $Executable @Arguments
    $exitCode = $LASTEXITCODE
    $results.Add([ordered]@{
        name = $Name
        command = "$Executable $($Arguments -join ' ')"
        startedAtUtc = $commandStarted.ToString("o")
        exitCode = $exitCode
        status = if ($exitCode -eq 0) { "pass" } else { "fail" }
    })
    if ($exitCode -ne 0) {
        throw "$Name failed with exit code $exitCode"
    }
}

try {
    $flutterCommand = (Get-Command flutter -ErrorAction Stop).Source
    $dartCommand = (Get-Command dart -ErrorAction Stop).Source
    $gitCommand = (Get-Command git -ErrorAction Stop).Source
    $gitTopLevel = & $gitCommand rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0 -or -not $gitTopLevel) {
        throw "Git repository access failed"
    }

    $version = (Get-Content -LiteralPath "VERSION" -Raw).Trim()
    $pubspecVersionLine = Select-String -LiteralPath "pubspec.yaml" -Pattern '^version:\s*(\S+)\s*$'
    if (-not $pubspecVersionLine) { throw "pubspec.yaml has no version field" }
    $pubspecVersion = $pubspecVersionLine.Matches[0].Groups[1].Value
    if ($version -ne $pubspecVersion) {
        throw "Version mismatch: VERSION=$version, pubspec.yaml=$pubspecVersion"
    }
    $readme = Get-Content -LiteralPath "README.md" -Raw
    $changelog = Get-Content -LiteralPath "CHANGELOG.md" -Raw
    if (-not $readme.Contains($version)) { throw "README.md does not contain version $version" }
    if (-not $changelog.Contains("## $version")) { throw "CHANGELOG.md has no $version entry" }
    $results.Add([ordered]@{ name = "version-consistency"; command = "static"; exitCode = 0; status = "pass" })

    $status = & $gitCommand status --porcelain
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect Git status" }
    if (-not $AllowDirty -and $status) {
        throw "Release verification requires a clean Git tree. Commit or stash changes, or use -AllowDirty for a pre-commit audit."
    }
    $results.Add([ordered]@{ name = "clean-tree"; command = "git status --porcelain"; exitCode = 0; status = if ($status) { "conditional" } else { "pass" } })

    $trackedSensitive = @(& $gitCommand ls-files -- "config.production.json" "admin/config.local.json" ".env" ".env.*" "*.jks" "*.keystore")
    if ($LASTEXITCODE -ne 0) { throw "Unable to inspect tracked sensitive files" }
    if ($trackedSensitive.Count -gt 0) {
        throw "Sensitive files are tracked: $($trackedSensitive -join ', ')"
    }
    $sourceFiles = @(& $gitCommand ls-files -- "*.dart" "*.json" "*.yaml" "*.yml" "*.md" "*.kts" "*.xml")
    if ($LASTEXITCODE -ne 0) { throw "Unable to enumerate source files for secret scan" }
    $secretPatterns = '(?i)(sk-[a-z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,}|BEGIN (RSA |EC )?PRIVATE KEY|api[_-]?key\s*[:=]\s*["''][^"'']{12,})'
    $secretHits = @()
    foreach ($file in $sourceFiles) {
        if (Test-Path -LiteralPath $file -PathType Leaf) {
            $match = Select-String -LiteralPath $file -Pattern $secretPatterns -AllMatches -ErrorAction SilentlyContinue
            if ($match) { $secretHits += $file }
        }
    }
    if ($secretHits.Count -gt 0) {
        $uniqueSecretHits = ($secretHits | Sort-Object -Unique) -join ', '
        throw "Potential secret pattern found in: $uniqueSecretHits"
    }
    $results.Add([ordered]@{ name = "tracked-secret-controls"; command = "git ls-files + pattern scan"; exitCode = 0; status = "pass" })

    $signingPropertiesPath = "android\key.properties"
    if ($RequireProductionSigning) {
        if (-not (Test-Path -LiteralPath $signingPropertiesPath)) {
            throw "Production signing required but android/key.properties is missing"
        }
        $signingProperties = @{}
        Get-Content -LiteralPath $signingPropertiesPath | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
                $signingProperties[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        foreach ($requiredKey in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
            if (-not $signingProperties[$requiredKey]) { throw "Missing $requiredKey in android/key.properties" }
        }
        if (-not (Test-Path -LiteralPath $signingProperties["storeFile"])) {
            throw "Release keystore does not exist at configured storeFile"
        }
        $results.Add([ordered]@{ name = "production-signing"; command = "android/key.properties + keystore existence"; exitCode = 0; status = "pass" })
    } else {
        $results.Add([ordered]@{ name = "production-signing"; command = "not required for code gate"; exitCode = $null; status = "conditional" })
    }

    Invoke-VI26Command -Name "locked-dependencies" -Executable $flutterCommand -Arguments @("pub", "get")
    Invoke-VI26Command -Name "format" -Executable $dartCommand -Arguments @("format", "--output=none", "--set-exit-if-changed", "lib", "test")
    Invoke-VI26Command -Name "analyze" -Executable $flutterCommand -Arguments @("analyze", "--fatal-infos")
    Invoke-VI26Command -Name "tests" -Executable $flutterCommand -Arguments @("test", "--reporter", "expanded")

    Push-Location -LiteralPath "admin"
    try {
        Invoke-VI26Command -Name "admin-locked-dependencies" -Executable $flutterCommand -Arguments @("pub", "get")
        Invoke-VI26Command -Name "admin-format" -Executable $dartCommand -Arguments @("format", "--output=none", "--set-exit-if-changed", "lib", "test")
        Invoke-VI26Command -Name "admin-analyze" -Executable $flutterCommand -Arguments @("analyze", "--fatal-infos")
        Invoke-VI26Command -Name "admin-tests" -Executable $flutterCommand -Arguments @("test", "--reporter", "expanded")
        Invoke-VI26Command -Name "admin-web-build" -Executable $flutterCommand -Arguments @("build", "web")
    } finally {
        Pop-Location
    }

    if (-not $SkipApk) {
        $buildArguments = @("build", "apk", "--release", "--split-per-abi")
        if (Test-Path -LiteralPath $ConfigFile) {
            $resolvedConfig = (Resolve-Path -LiteralPath $ConfigFile).Path
            $buildArguments += "--dart-define-from-file=$resolvedConfig"
        }
        Invoke-VI26Command -Name "release-apks" -Executable $flutterCommand -Arguments $buildArguments
    } else {
        $results.Add([ordered]@{ name = "release-apks"; command = "skipped by -SkipApk"; exitCode = $null; status = "skipped" })
    }
} catch {
    $overall = "fail"
    $failureMessage = $_.Exception.Message
    Write-Host "`n[VI26] FAILED: $failureMessage" -ForegroundColor Red
} finally {
    $gitSha = (& git rev-parse HEAD 2>$null)
    $gitBranch = (& git branch --show-current 2>$null)
    $flutterFrameworkVersion = $null
    $dartSdkVersion = $null
    $flutterChannel = $null
    if ($flutterCommand) {
        try {
            $flutterVersionOutput = & $flutterCommand --version --machine 2>$null
            if ($LASTEXITCODE -eq 0 -and $flutterVersionOutput) {
                $flutterVersion = $flutterVersionOutput | ConvertFrom-Json
                $flutterFrameworkVersion = $flutterVersion.frameworkVersion
                $dartSdkVersion = $flutterVersion.dartSdkVersion
                $flutterChannel = $flutterVersion.channel
            }
        } catch {
            Write-Warning "Could not record Flutter version: $($_.Exception.Message)"
        }
    }
    $artifacts = @()
    if (-not $SkipApk -and (Test-Path -LiteralPath "build\app\outputs\flutter-apk")) {
        $artifacts = @(Get-ChildItem -LiteralPath "build\app\outputs\flutter-apk" -Filter "*-release.apk" -File | ForEach-Object {
            [ordered]@{
                path = $_.FullName.Substring($projectRoot.Length + 1)
                bytes = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        })
    }
    $evidence = [ordered]@{
        schema = "emmaprep-vi26-evidence-v1"
        overall = $overall
        failure = $failureMessage
        version = if (Test-Path -LiteralPath "VERSION") { (Get-Content -LiteralPath "VERSION" -Raw).Trim() } else { $null }
        commit = "$gitSha".Trim()
        branch = "$gitBranch".Trim()
        allowDirty = [bool]$AllowDirty
        apkBuildSkipped = [bool]$SkipApk
        productionSigningRequired = [bool]$RequireProductionSigning
        startedAtUtc = $startedAt.ToString("o")
        finishedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        environment = [ordered]@{
            os = [System.Environment]::OSVersion.VersionString
            flutter = $flutterFrameworkVersion
            dart = $dartSdkVersion
            channel = $flutterChannel
        }
        commands = $results
        artifacts = $artifacts
        physicalDeviceAcceptance = "separate evidence required"
        rollbackEvidence = "separate evidence required"
    }
    $evidenceDirectory = Join-Path $projectRoot "docs\verification"
    New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
    $evidencePath = Join-Path $evidenceDirectory "latest.json"
    $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $evidencePath -Encoding utf8
    Write-Host "[VI26] Evidence written to $evidencePath"
}

if ($overall -ne "pass") {
    throw "VI26 automated gates failed: $failureMessage"
}
Write-Host "`n[VI26] Automated gates passed." -ForegroundColor Green
