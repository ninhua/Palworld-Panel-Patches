# Full package v0.12.4

这是完整仓库包，不是增量升级包。

## 使用

```bash
unzip Palworld-Panel-Patches-v0.12.4-full.zip
cd Palworld-Panel-Patches-v0.12.4-full
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
```

作为现有 Git 仓库的完整替换内容时，先备份 `.git`，清空工作树中受版本控制的旧文件，再复制本目录内容并提交。

活动目标固定为官方 PalPanel `v1.3.0`，stable patch version 为 `0.8.1`。
