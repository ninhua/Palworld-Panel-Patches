# Upgrade v0.3.0 → v0.4.0

覆盖仓库根目录：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.3.0-to-v0.4.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add .
git commit -m "feat: add first uitok dev patch"
git push origin main
```

验证通过后运行：

```text
Actions
→ Build uitok dev patch
→ Run workflow
```

成功后下载 Artifact：

```text
uitok-dev-v1.2.2-patch-0.1.0-dev.1-5e3c0bce9d33
```
