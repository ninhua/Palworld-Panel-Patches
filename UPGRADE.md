# Upgrade v0.12.0 / v0.12.1 → v0.12.2

本次升级同时修复 stable 迁移检查点和 Release SHA256SUMS 生成/消费链路。

## 迁移检查点

现有补丁链包含后置纠正补丁：

```text
0008-add-base-worker-browser.patch
0009-add-base-feed-box-summary.patch
0010-fix-missing-base-worker-handler.patch

0011-allow-http-service-endpoints.patch
0012-restore-ai-translation-net-import.patch
```

`0008` 单独应用后会暂时引用尚未由 `0010` 补齐的 handler；`0011` 单独应用后也需要 `0012` 恢复编译依赖。因此不能在每个补丁后都强制编译并回滚。

v0.12.2 仍逐补丁执行 SHA-256、apply、diff 检查和状态记录，但只在 catalog 声明的检查点执行累计编译：

```text
0008 + 0009 + 0010 → compile/lint checkpoint
0011 + 0012        → compile/lint checkpoint
```

最终仍必须通过 merged patch clean-room 全量测试，发布门槛没有降低。

## Release 校验

新增统一 `release-checksums.py`：

- 生成端只在四个顶层资产全部定稿后写入 SHA256SUMS；
- 消费端兼容 `hash  filename`、`hash *filename` 和 `./filename`；
- 拒绝重复文件名、不安全路径、缺失文件和哈希不匹配；
- 五文件集合必须严格一致。

## 升级

```bash
unzip Palworld-Panel-Patches-upgrade-v0.12.x-to-v0.12.2.zip
cd Palworld-Panel-Patches-upgrade-v0.12.x-to-v0.12.2
bash apply-upgrade.sh /path/to/Palworld-Panel-Patches
```

然后执行：

```bash
cd /path/to/Palworld-Panel-Patches
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
```

stable patch version 继续使用 `0.8.1`。失败的 `migration/v1.3.0` 分支会在下一次运行时由新的 candidate 报告覆盖。若补丁链最终没有源码差异，Action 会持久化 `no-change` candidate 并以 `no-release-needed` 成功结束。
