# Upgrade v0.12.9 → v0.12.10

本增量包让“操作审计”显示后端现有响应摘要，并将 stable patch version 提升到 `0.8.4`。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.9-to-v0.12.10.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.10: display audit response summaries"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。预期 Release tag：`uitok-stable-v1.3.0-p0.8.4`。
