param(
    [string]$Language = "zh",
    [string]$Country = "CN",
    [string]$Region = "CN",
    [switch]$UseRealProfile,
    [string]$ProfileRoot = "_tb_override",
    [switch]$Wait
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$scriptDir = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

$installDir = $scriptDir
$exePath = Join-Path $installDir "TourBox Console.exe"

if (-not [System.IO.Path]::IsPathRooted($ProfileRoot)) {
    $ProfileRoot = Join-Path $scriptDir $ProfileRoot
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Cannot find TourBox Console.exe at $exePath"
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Value
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Value,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Copy-MissingItems {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$DestDir
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $DestDir | Out-Null

    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        $target = Join-Path $DestDir $_.Name

        if ($_.PSIsContainer) {
            Copy-MissingItems -SourceDir $_.FullName -DestDir $target
        } else {
            if (-not (Test-Path -LiteralPath $target)) {
                Copy-Item -LiteralPath $_.FullName -Destination $target
            }
        }
    }
}

function Ensure-TourBoxUiConfigLockedToAutoLocale {
    param(
        [Parameter(Mandatory = $true)][string]$UiConfigPath,
        [string]$SeedUiConfigPath
    )

    if (Test-Path -LiteralPath $UiConfigPath) {
        $ui = Get-Content -LiteralPath $UiConfigPath -Raw
    } elseif ($SeedUiConfigPath -and (Test-Path -LiteralPath $SeedUiConfigPath)) {
        $ui = Get-Content -LiteralPath $SeedUiConfigPath -Raw
    } else {
        $ui = $null
    }

    if ([string]::IsNullOrWhiteSpace($ui)) {
        $ui = @"
<UIConfig>
  <keySettingAlwayExpand>true</keySettingAlwayExpand>
  <firstOpen>true</firstOpen>
  <refeshRatio>50</refeshRatio>
  <crossWindowRatio>0.7</crossWindowRatio>
  <crossWindowAlpha>153</crossWindowAlpha>
  <crossWindowHeightRatio>0.25</crossWindowHeightRatio>
  <crossHL>true</crossHL>
  <holdingTourAction>2</holdingTourAction>
  <pressTourAction>1</pressTourAction>
  <uiSKin>1</uiSKin>
  <uiLanguage>0</uiLanguage>
  <languageAuto>true</languageAuto>
</UIConfig>
"@
    }

    # Keep the rest of the user's config intact. Only force automatic language
    # selection so the Java zh-CN locale override can drive TourBox into Chinese.
    if ($ui -match "<languageAuto>.*?</languageAuto>") {
        $ui = $ui -replace "<languageAuto>.*?</languageAuto>", "<languageAuto>true</languageAuto>"
    } else {
        $ui = $ui -replace "</UIConfig>", "  <languageAuto>true</languageAuto>`r`n</UIConfig>"
    }

    Write-Utf8NoBom -Path $UiConfigPath -Value $ui
}

$savedEnv = @{
    APPDATA           = $env:APPDATA
    LOCALAPPDATA      = $env:LOCALAPPDATA
    JAVA_TOOL_OPTIONS = $env:JAVA_TOOL_OPTIONS
    _JAVA_OPTIONS     = $env:_JAVA_OPTIONS
    LANG              = $env:LANG
    LC_ALL            = $env:LC_ALL
}

try {
    $realRoamRoot = $savedEnv.APPDATA
    $realLocalRoot = $savedEnv.LOCALAPPDATA
    $realRoamCfgDir = Join-Path $realRoamRoot "TourBox Console"
    $realLocalCfgDir = Join-Path $realLocalRoot "TourBox Console"

    if ($UseRealProfile) {
        $profileRoamRoot = $realRoamRoot
        $profileLocalRoot = $realLocalRoot
        $profileCfgDir = $realRoamCfgDir
        $profileUi = Join-Path $profileCfgDir "UIConfig"

        Ensure-TourBoxUiConfigLockedToAutoLocale `
            -UiConfigPath $profileUi `
            -SeedUiConfigPath $profileUi
    } else {
        $profileRoamRoot = Join-Path $ProfileRoot "Roaming"
        $profileLocalRoot = Join-Path $ProfileRoot "Local"
        $profileCfgDir = Join-Path $profileRoamRoot "TourBox Console"
        $profileLocalCfgDir = Join-Path $profileLocalRoot "TourBox Console"

        New-Item -ItemType Directory -Force -Path $profileCfgDir, $profileLocalCfgDir | Out-Null

        # Import existing real settings only when the corresponding files do not
        # already exist in the override profile. This preserves all later changes
        # made by TourBox inside _tb_override.
        Copy-MissingItems -SourceDir $realRoamCfgDir -DestDir $profileCfgDir
        Copy-MissingItems -SourceDir $realLocalCfgDir -DestDir $profileLocalCfgDir

        $profileUi = Join-Path $profileCfgDir "UIConfig"
        $realUi = Join-Path $realRoamCfgDir "UIConfig"

        Ensure-TourBoxUiConfigLockedToAutoLocale `
            -UiConfigPath $profileUi `
            -SeedUiConfigPath $realUi

        $env:APPDATA = $profileRoamRoot
        $env:LOCALAPPDATA = $profileLocalRoot
    }

    # Lock Java-side locale to Simplified Chinese / China. Right-click
    # "Run with PowerShell" uses these defaults because no arguments are needed.
    $overrideArgs = @(
        "-Duser.language=$Language"
        "-Duser.country=$Country"
        "-Duser.region=$Region"
        "-Dfile.encoding=UTF-8"
        "-Dsun.stdout.encoding=UTF-8"
        "-Dsun.stderr.encoding=UTF-8"
    ) -join " "

    $env:JAVA_TOOL_OPTIONS = $overrideArgs
    $env:_JAVA_OPTIONS = $overrideArgs

    # Some frameworks also inspect POSIX-style locale variables. They do not
    # change the Windows system locale, but they are harmless and useful when read.
    $env:LANG = "${Language}_${Country}.UTF-8"
    $env:LC_ALL = "${Language}_${Country}.UTF-8"

    $proc = Start-Process `
        -FilePath $exePath `
        -WorkingDirectory $installDir `
        -WindowStyle Hidden `
        -PassThru

    $profileBase = $profileCfgDir

    Write-Output "Launched PID: $($proc.Id)"
    Write-Output "Profile: $profileBase"
    Write-Output "UIConfig: $profileUi"
    Write-Output "Locale: $Language-$Country / region=$Region"
    Write-Output "Overrides: $overrideArgs"
    Write-Output "Log: $(Join-Path $profileBase 'tourbox.log')"

    if ($Wait) {
        Start-Sleep -Seconds 8

        if (-not $proc.HasExited) {
            Write-Output "Process still running after wait window."
        }

        $logPath = Join-Path $profileBase "tourbox.log"
        if (Test-Path -LiteralPath $logPath) {
            if (Get-Command rg -ErrorAction SilentlyContinue) {
                rg -n "user\\.country|user\\.language|user\\.region|sun\\.jnu\\.encoding|native\\.encoding|sun\\.stdout\\.encoding|sun\\.stderr\\.encoding|file\\.encoding|initCTYPE|locale=|country=|lang=|Current user set local|Current User locale|User preference locale is|languageAuto=" $logPath
            } else {
                Select-String -Path $logPath -Pattern "user\.country|user\.language|user\.region|sun\.jnu\.encoding|native\.encoding|sun\.stdout\.encoding|sun\.stderr\.encoding|file\.encoding|initCTYPE|locale=|country=|lang=|Current user set local|Current User locale|User preference locale is|languageAuto="
            }
        }
    }
} finally {
    $env:APPDATA = $savedEnv.APPDATA
    $env:LOCALAPPDATA = $savedEnv.LOCALAPPDATA
    $env:JAVA_TOOL_OPTIONS = $savedEnv.JAVA_TOOL_OPTIONS
    $env:_JAVA_OPTIONS = $savedEnv._JAVA_OPTIONS
    $env:LANG = $savedEnv.LANG
    $env:LC_ALL = $savedEnv.LC_ALL
}
