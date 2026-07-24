# Upgrade v0.12.8 → v0.12.9

本增量包新增 PalPanel 补丁热更新任务，并将 stable patch version 提升到 `0.8.3`。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.8-to-v0.12.9.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.9: add verified panel patch hot update"
git push origin main
```

随后手动运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。预期 Release tag：`uitok-stable-v1.3.0-p0.8.3`。

`0.8.3` 是首个包含热更新入口的版本。安装该版本后，面板可从任务队列或开服向导直接更新后续同目标 stable patch，例如 `0.8.4`。
