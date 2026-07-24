# Upgrade v0.12.7 → v0.12.8

本增量包修复玩家备注对实时在线玩家返回 `player not found`，并将 stable patch version 提升到 `0.8.2`。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.7-to-v0.12.8.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.8: resolve annotations against merged online players"
git push origin main
```

随后手动运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。预期 Release tag：`uitok-stable-v1.3.0-p0.8.2`。
