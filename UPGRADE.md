# Upgrade v0.10.3 → v0.11.0

本次升级新增上游稳定版每日自动发布能力。

## 行为

```text
每天检查一次上游正式 Release
→ 选择最高稳定版本
→ 若已有同名稳定补丁 Release，则跳过
→ 若版本在明确不兼容列表中，则跳过
→ 应用当前完整补丁链并运行完整构建验证
→ 成功后直接创建稳定 Release
```

不会创建 PR 或 Issue。失败时只保留 GitHub Actions 日志，不提交仓库变更，也不发布资产。

新增文件：

```text
.github/workflows/auto-release-uitok-stable.yml
projects/uitok-palworld-panel/automation/README.md
projects/uitok-palworld-panel/automation/config.json
projects/uitok-palworld-panel/automation/incompatible-versions.json
projects/uitok-palworld-panel/automation/select-latest-version.py
projects/uitok-palworld-panel/automation/retarget-stable-source.py
projects/uitok-palworld-panel/automation/build-stable-release.sh
projects/uitok-palworld-panel/automation/smoke-stable.sh
projects/uitok-palworld-panel/automation/tests/test-automation.sh
```

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.10.3-to-v0.11.0.zip
cp -a Palworld-Panel-Patches-upgrade-v0.10.3-to-v0.11.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "feat: automate stable patch releases"
git push origin main
```

仓库设置必须允许 GitHub Actions 使用读写权限创建 Release：

```text
Settings → Actions → General → Workflow permissions
→ Read and write permissions
```

无需允许 Actions 创建 Pull Request。

首次推送后，可以在 Actions 中手动运行 `Auto release uitok stable patch`，留空版本即自动选择最新稳定版；之后每天自动检查一次。
