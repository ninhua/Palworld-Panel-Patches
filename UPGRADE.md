# Upgrade v0.11.1 → v0.11.2

本次升级修复稳定版 Action 的补丁应用错误：

```text
backend/internal/pallocalize/localize_test.go: patch does not apply
```

该冲突来自上游测试文件结构变化，不代表存储图标或容器名称核心实现不兼容。

新逻辑：

```text
先执行完整 git apply --check
→ 成功：正常应用
→ 失败：检查是否只有已知 pallocalize 测试路径冲突
→ 其他文件全部可应用：排除旧测试 hunk，并生成独立等价测试文件
→ 仍有其他冲突：Workflow 失败，不发布 Release
```

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.11.1-to-v0.11.2.zip
cp -a Palworld-Panel-Patches-upgrade-v0.11.1-to-v0.11.2/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "fix: rebase pallocalize tests during stable migration"
git push origin main
```

然后重新运行失败的：

```text
Auto release uitok stable patch
```

无需修改生产启动脚本或 `palpanel-feature-patch.sh`。
