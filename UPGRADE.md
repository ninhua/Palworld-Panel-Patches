# Upgrade v0.2.3 → v0.2.4

覆盖仓库根目录：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.2.3-to-v0.2.4/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add VERSION README.md CHANGELOG.md
git commit -m "fix: synchronize scaffold version metadata"
git push origin main
```

本次修复对应错误：

```text
[ERROR] README.md 中的骨架版本与 VERSION 不一致
```

升级后应满足：

```text
VERSION: 0.2.4
README.md: 骨架版本：`v0.2.4`
CHANGELOG.md: ## v0.2.4
```
