# Upgrade v0.2.2 → v0.2.3

覆盖仓库根目录：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.2.2-to-v0.2.3/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add .
git commit -m "fix: migrate actions to Node 24"
git push origin main
```

关键 Action 版本：

```yaml
uses: actions/checkout@v6
uses: actions/setup-python@v6
```

这两个版本原生使用 Node.js 24。

## 临时版本映射

开发时可以使用 v1.2.1 源码测试 v1.2.2，但不能把 `upstream.version`
写成 v1.2.2。请使用新增目录：

```text
projects/uitok-palworld-panel/patches/v1.2.2-compat-v1.2.1/
```
