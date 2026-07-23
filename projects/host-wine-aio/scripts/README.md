# Host Wine AIO scripts

## linux-palworld-oneclick-v1.0.40.sh

该版本接入固定 PalPanel 功能补丁预发布通道。

默认：

```text
PALWORLD_LINUX_PANEL_PATCH_ENABLED=1
PALWORLD_LINUX_PANEL_PATCH_REQUIRED=0
```

远程补丁不存在或校验失败时继续启动原版。强制要求补丁：

```text
PALWORLD_LINUX_PANEL_PATCH_REQUIRED=1
```

本地测试：

```text
PALWORLD_LINUX_PANEL_PATCH_FILE=/absolute/path/to/patch-package.tar.gz
```

关闭新补丁下载不会自动卸载已经应用的补丁。恢复原版应重新安装官方面板版本，或者从状态文件记录的 `backup_path` 恢复。
