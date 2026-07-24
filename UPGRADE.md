# Upgrade v0.12.10 → v0.12.11

本增量包修复 stable build 在 `clean-room-go-tests` 阶段失败的问题。

根因是 `0014-add-panel-patch-hot-update.patch` 注册了三个新 API 路由，但没有把它们加入
`docs/openapi.yaml`。上游路由契约测试会逐项比对 Gin 路由与 OpenAPI operation，因此全量
Go 测试失败。

本次新增 `0016-fix-panel-patch-update-openapi-contract.patch`，补齐 OpenAPI 声明并增加显式路由断言。
此前 `0.8.4` Release 未创建，所以 stable patch version 保持 `0.8.4`。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.10-to-v0.12.11.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.11: fix patch update OpenAPI contract"
git push origin main
```

随后重新运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。
预期 Release tag 仍为 `uitok-stable-v1.3.0-p0.8.4`。
