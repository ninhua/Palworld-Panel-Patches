# Upgrade v0.5.1 → v0.6.0

本版本新增只读的基地仓库浏览功能，并将补丁版本升级到 `0.3.0-dev.1`。

覆盖仓库：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.5.1-to-v0.6.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
```

验证：

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "feat: add read-only base storage browser"
git push origin main
```

先运行：

```text
Actions → Build uitok dev patch → Run workflow
```

预期 Artifact：

```text
uitok-dev-v1.2.2-patch-0.3.0-dev.1-5e3c0bce9d33
```

Build 完整通过后再运行：

```text
Actions → Release uitok dev patch → Run workflow
```

预期标签：

```text
uitok-dev-v1.2.2-p0.3.0-dev.1
```

在新 Release 资产完成发布并验收前，部署脚本不要提前切换默认补丁版本。
