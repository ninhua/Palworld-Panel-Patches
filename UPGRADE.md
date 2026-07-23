# Upgrade v0.5.0 → v0.5.1

本修订只修复 `0002-add-base-custom-names.patch` 中的 Go 测试编译错误，不改变补丁版本和 Release 标签。

覆盖仓库：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.5.0-to-v0.5.1/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
```

验证：

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add VERSION README.md CHANGELOG.md UPGRADE.md \
  projects/uitok-palworld-panel/patches/dev-v1.2.2/source/0002-add-base-custom-names.patch \
  projects/uitok-palworld-panel/patches/dev-v1.2.2/source/SHA256SUMS
git commit -m "fix: use Gin context in base custom name test"
git push origin main
```

然后重新运行：

```text
Actions → Build uitok dev patch → Run workflow
```

预期补丁版本和标签仍为：

```text
0.2.0-dev.1
uitok-dev-v1.2.2-p0.2.0-dev.1
```

失败的构建没有发布 Release，因此无需增加补丁版本号。
