# Host Wine AIO

这是你自己编写的简幻欢 Docker + Wine 启动兼容层的补丁接入区。

它不是原面板源码，也不是 Jiaayu 面板源码。

## 职责

- 检测当前原面板版本；
- 查找精确兼容补丁；
- 下载和校验 Release 资产；
- staging 安装；
- 记录补丁状态；
- 失败回滚；
- 调用现有 Wine、Docker shim、代理和侧车逻辑。

## 建议接入函数

```bash
detect_panel_patch
download_panel_patch
apply_panel_patch
verify_panel_patch
record_panel_patch_state
```
