# Hatch Replay Pet

一个轻量级 Windows 即时回放录屏工具，带桌面角色控制面板。

## 功能

- 后台缓存最近一段屏幕录制。
- `Alt + F9` 开始或停止缓存。
- `Alt + F10` 保存最近缓存片段。
- 使用内置 FFmpeg 和 NVIDIA NVENC 编码。
- 输出视频保存到：`%USERPROFILE%\Videos\SimpleReplay`
- 支持桌面快捷方式和开始菜单快捷方式。

## 安装

下载发布包后解压，双击：

```text
Install.cmd
```

安装目录：

```text
%LOCALAPPDATA%\Programs\HatchReplayPet
```

安装完成后会创建：

```text
桌面\Hatch Replay Pet.lnk
开始菜单\Hatch Replay Pet\Hatch Replay Pet.lnk
```

## 使用

双击桌面图标启动。角色出现后：

- 单击角色展开控制面板。
- 右键角色打开快捷菜单。
- 点击“开始”或按 `Alt + F9` 开始缓存。
- 点击“保存”或按 `Alt + F10` 保存回放。
- 点击“打开输出文件夹”查看视频。

## 卸载

双击安装目录里的：

```text
Uninstall.cmd
```

卸载会删除安装目录、桌面快捷方式和开始菜单快捷方式。

## 注意

- 需要 Windows。
- 录制依赖显卡 NVENC，建议使用 NVIDIA 显卡。
- 某些受保护窗口或 HDR/多显示器场景可能无法正常捕获。
