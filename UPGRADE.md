# Upgrade v0.11.0 → v0.11.1

本次升级修正稳定版自动发布的派生规则。

旧行为：

```text
每个新的上游稳定版本
→ 都从固定 dev 补丁轨道重新迁移
```

新行为：

```text
查找目标版本之前最高的已发布 stable Release
→ 下载并校验该 Release 的合并补丁
→ 将上一个稳定补丁应用到新的官方稳定版源码
→ 完整构建和测试
→ 发布新的 stable Release
```

只有第一次不存在更早 stable Release 时，才使用：

```text
projects/uitok-palworld-panel/patches/dev-v1.2.2
```

作为首次迁移源。

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.11.0-to-v0.11.1.zip
cp -a Palworld-Panel-Patches-upgrade-v0.11.0-to-v0.11.1/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "fix: derive stable patches from previous stable release"
git push origin main
```

然后在 Actions 手动运行一次：

```text
Auto release uitok stable patch
```

后续仍每天 UTC 01:17 自动检查。无需修改启动脚本。
