# Upgrade v0.12.13 → v0.12.14

本增量修复 PalPanel 补丁热更新在共享出口 IP 上命中 GitHub 匿名 REST API 限额后返回 `403 Forbidden` 的问题。stable patch version 保持 `0.8.6`，因为此前 blocked workflow 没有创建对应 immutable Release。

新增 `0019-avoid-github-api-rate-limit.patch`：

- 优先读取仓库已发布 stable 工作区的 `workspace.json`；
- 只接受 `state=released`、`verified=true`、目标版本和 Release tag 精确匹配的记录；
- 由 Release tag 构造补丁包、`manifest.json` 和 `SHA256SUMS` 下载地址；
- GitHub REST API 仅作为回退，不再是热更新的单点依赖；
- 兼容一键部署侧补丁 Token 变量及 `GITHUB_TOKEN` / `GH_TOKEN`；
- 原有 checksum、manifest、平台、功能和二进制 SHA-256 校验保持不变。

`player-presence-history` 暂时设置为 optional feature，使其迁移问题不会阻断本次热更新修复发布。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.13-to-v0.12.14.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.14: avoid GitHub API rate limits in patch hot update"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。
预期 Release tag 为 `uitok-stable-v1.3.0-p0.8.6`。
