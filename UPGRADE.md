# Upgrade v0.2.0 → v0.2.1

在仓库根目录执行：

```bash
cp -a /path/to/Palworld-Panel-Patches-upgrade-v0.2.0-to-v0.2.1/. .
git add .
git commit -m "chore: upgrade scaffold to v0.2.1"
git push origin main
```

覆盖文件包括：

- VERSION、README、CHANGELOG；
- JSON Schema；
- CI 和本地验证脚本；
- `.gitattributes`；
- MIT LICENSE；
- CI Python 依赖。

升级后运行：

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```
