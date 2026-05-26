# TourBox 区域语言覆盖启动脚本

[English](./README.md) | [简体中文](./README.zh-CN.md)

> TourBox Console 的非官方 PowerShell 启动脚本。  
> 仅供学习交流、技术研究和临时个人使用。

## 声明

本项目与 TourBox 官方无关，非官方维护，也未获得官方背书。

本脚本不会：

- 破解、补丁、修改或重分发 TourBox Console；
- 包含 `TourBox Console.exe`；
- 包含任何 TourBox 驱动、DLL、安装包、固件或专有资源；
- 绕过授权或产品激活。

它只是在启动本机已有的 TourBox Console 时，为该进程提供受控的运行时语言、地区和配置环境。

请仅配合你已合法安装的 TourBox Console 使用。

## 适用场景

本脚本主要适用于以下用户：

1. 原先购买或使用的是国内版 TourBox；
2. 后来出国，或修改了 Windows 区域相关设置；
3. TourBox Console 出现乱码、地区识别异常或语言相关问题；
4. 不希望修改 Windows 显示语言或 `Current system locale`；
5. 只需要一个针对 TourBox Console 的临时单应用规避方案。

## 工作原理

脚本会用以下默认运行时参数启动 `TourBox Console.exe`：

```powershell
-Language zh
-Country CN
-Region CN
```

同时为被启动进程设置 Java 相关 locale 参数：

```text
-Duser.language=zh
-Duser.country=CN
-Duser.region=CN
-Dfile.encoding=UTF-8
-Dsun.stdout.encoding=UTF-8
-Dsun.stderr.encoding=UTF-8
```

脚本不会修改 Windows 全局显示语言、Windows 区域设置或 Windows 的 `Current system locale`。

## 文件放置方式

请将脚本放在 `TourBox Console.exe` 同级目录。

推荐结构：

```text
TourBox Console/
├─ TourBox Console.exe
├─ LocationOverride.ps1
├─ README.md
├─ README.zh-CN.md
└─ _tb_override/        # 首次运行后自动创建
```

## 使用方法

1. 先完全退出 TourBox Console，包括托盘和后台进程。
2. 将 `LocationOverride.ps1` 放到 `TourBox Console.exe` 同级目录。
3. 右键 `LocationOverride.ps1`。
4. 选择 **Run with PowerShell**。
5. TourBox Console 运行期间，请保持 PowerShell 终端窗口开启。

如果 Windows 阻止脚本运行，可以执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\LocationOverride.ps1
```

该绕过方式只对当前命令生效。

## 配置文件行为

默认情况下，脚本使用隔离配置目录，而不是直接使用真实用户配置目录。

隔离配置目录位于：

```text
_tb_override\Roaming\TourBox Console
_tb_override\Local
```

被启动的 TourBox 进程会收到以下环境变量覆盖：

```text
APPDATA      -> _tb_override\Roaming
LOCALAPPDATA -> _tb_override\Local
```

这意味着在 TourBox Console 内修改的配置通常会写入 `_tb_override`，而不是直接写入你的 Windows 用户真实配置目录。

## UIConfig 行为

首次运行时，如果隔离目录中不存在 `UIConfig`，脚本会尽量从真实 TourBox 配置中初始化。

初始化之后，隔离配置会被保留并继续复用。启动器不应在每次启动时覆盖你的配置。

脚本会确保存在以下配置项：

```xml
<languageAuto>true</languageAuto>
```

这使 TourBox Console 可以跟随脚本强制设置的运行时区域：

```text
Language = zh
Country  = CN
Region   = CN
```

其他配置字段应会被保留。

## 可选：使用真实配置目录

如需禁用 `_tb_override` 隔离配置，可运行：

```powershell
.\LocationOverride.ps1 -UseRealProfile
```

这会使用当前 Windows 用户下的真实 TourBox 配置。

仅在明确理解隔离配置与真实配置差异时使用该选项。

## 重置

如需重置隔离配置：

1. 退出 TourBox Console。
2. 删除 `_tb_override`。
3. 重新运行 `LocationOverride.ps1`。

该目录会在下次运行时自动重新创建。

## 卸载方式

本项目不会向 Windows 安装任何内容。

移除方式：

1. 退出 TourBox Console。
2. 删除 `LocationOverride.ps1`。
3. 如果不再需要隔离配置，删除 `_tb_override`。

## 排障

### TourBox 仍然显示错误语言

请确认没有旧的 `TourBox Console.exe` 进程仍在运行。打开任务管理器，结束所有 TourBox 相关进程后，再通过脚本启动。

### 设置没有保存

检查以下目录中的文件是否有更新：

```text
_tb_override\Roaming\TourBox Console
```

如果没有更新，说明 TourBox 可能使用 Windows Known Folder API，而不是读取 `APPDATA` 环境变量。此时可以尝试：

```powershell
.\LocationOverride.ps1 -UseRealProfile
```

### PowerShell 窗口闪退

从已有 PowerShell 窗口中运行脚本以查看错误：

```powershell
cd "C:\Path\To\TourBox Console"
powershell -ExecutionPolicy Bypass -File .\LocationOverride.ps1 -Wait
```

## 说明

这是临时规避方案，不是根本修复。
