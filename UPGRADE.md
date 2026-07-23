# Upgrade v0.2.1 → v0.2.2

将本目录内容覆盖到仓库根目录：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.2.1-to-v0.2.2/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add .
git commit -m "fix: configure pip cache and target v1.2.2"
git push origin main
```

修复后的关键配置：

```yaml
- name: Set up Python
  uses: actions/setup-python@v5
  with:
    python-version: "3.12"
    cache: pip
    cache-dependency-path: requirements-ci.txt
```

推送后重新查看 Actions。预期 `Validate repository` 通过。
