# TourBox Locale Override Launcher

[English](./README.md) | [简体中文](./README.zh-CN.md)

> Unofficial PowerShell launcher for TourBox Console.  
> For learning, technical research, and temporary personal use only.

## Disclaimer

This project is not affiliated with, endorsed by, or maintained by TourBox.

This script does not:

- crack, patch, modify, or redistribute TourBox Console;
- include `TourBox Console.exe`;
- include any TourBox driver, DLL, installer, firmware, or proprietary asset;
- bypass licensing or product activation.

It only launches an existing local installation of TourBox Console with a controlled runtime locale/profile environment.

Use it only with a legally installed copy of TourBox Console.

## Intended use case

This script is intended for users who:

1. originally purchased or used a China-region TourBox;
2. later moved abroad or changed Windows regional settings;
3. see incorrect locale behavior, or China-region compatibility issues in TourBox Console;
4. do not want to change Windows display language or `Current system locale`;
5. need a temporary per-application workaround.

## How it works

The script starts `TourBox Console.exe` with the following default runtime overrides:

```powershell
-Language zh
-Country CN
-Region CN
```

It also sets Java-related locale options for the launched process:

```text
-Duser.language=zh
-Duser.country=CN
-Duser.region=CN
-Dfile.encoding=UTF-8
-Dsun.stdout.encoding=UTF-8
-Dsun.stderr.encoding=UTF-8
```

The script does not change global Windows language, Windows region, or Windows `Current system locale`.

## File placement

Put the script in the same directory as `TourBox Console.exe`.

Recommended layout:

```text
TourBox Console/
├─ TourBox Console.exe
├─ LocationOverride.ps1
├─ README.md
├─ README.zh-CN.md
└─ _tb_override/        # Created automatically after first run
```

## Usage

1. Fully exit TourBox Console, including the tray/background process.
2. Put `LocationOverride.ps1` next to `TourBox Console.exe`.
3. Right-click `LocationOverride.ps1`.
4. Select **Run with PowerShell**.
5. Keep the PowerShell terminal open while TourBox Console is running.

If Windows blocks script execution, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\LocationOverride.ps1
```

The bypass applies only to that command.

## Configuration behavior

By default, the script uses an isolated profile instead of the real user profile.

The isolated profile is stored under:

```text
_tb_override\Roaming\TourBox Console
_tb_override\Local
```

The launched process receives these environment overrides:

```text
APPDATA      -> _tb_override\Roaming
LOCALAPPDATA -> _tb_override\Local
```

This means configuration changes made inside TourBox Console should be written to `_tb_override`, not directly to your normal Windows user profile.

## UIConfig behavior

On first run, if no isolated `UIConfig` exists, the script may initialize one from the real TourBox profile.

After initialization, the isolated configuration is preserved and reused. The launcher should not overwrite your configuration on every start.

The script ensures this value exists:

```xml
<languageAuto>true</languageAuto>
```

This lets TourBox Console follow the forced runtime locale:

```text
Language = zh
Country  = CN
Region   = CN
```

Other configuration fields should be preserved.

## Optional: use the real profile

To run without `_tb_override` profile isolation:

```powershell
.\LocationOverride.ps1 -UseRealProfile
```

This uses your real Windows TourBox profile.

Use this option only if you understand the difference between the isolated profile and the real profile.

## Reset

To reset the isolated profile:

1. Exit TourBox Console.
2. Delete `_tb_override`.
3. Run `LocationOverride.ps1` again.

The folder will be recreated automatically.

## Uninstall

This project does not install anything into Windows.

To remove it:

1. Exit TourBox Console.
2. Delete `LocationOverride.ps1`.
3. Delete `_tb_override` if you no longer need the isolated profile.

## Troubleshooting

### TourBox still shows the wrong language

Make sure no old `TourBox Console.exe` process is still running. Check Task Manager and exit all TourBox-related processes before launching through the script.

### Settings are not saved

Check whether files under this directory are updated:

```text
_tb_override\Roaming\TourBox Console
```

If they are not updated, TourBox may be using Windows Known Folder APIs instead of the `APPDATA` environment variable. In that case, try:

```powershell
.\LocationOverride.ps1 -UseRealProfile
```

### PowerShell window closes immediately

Run the script from an existing PowerShell window to see the error:

```powershell
cd "C:\Path\To\TourBox Console"
powershell -ExecutionPolicy Bypass -File .\LocationOverride.ps1 -Wait
```

## Notes

This is a workaround, not a permanent fix.
