# Upgrade v0.6.0 → v0.6.1

本修订只修复 Build/Release 的 `/api/patch/info` 冒烟断言。

原错误要求功能数组精确等于两个旧功能，导致新增 `base-storage-browser` 后误判失败。修复后检查所需功能是否均存在，不依赖数组顺序，也允许未来增加其他功能。

覆盖仓库：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.6.0-to-v0.6.1/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "fix: accept storage feature in patch smoke test"
git push origin main
```

重新运行：

```text
Actions → Build uitok dev patch → Run workflow
```

Build 通过后再运行 Release。补丁版本仍为 `0.3.0-dev.1`。
