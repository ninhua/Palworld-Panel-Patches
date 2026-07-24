# Upgrade v0.12.12 → v0.12.13

本增量包新增玩家在线时长与在线历史，并将 stable patch version 提升到 `0.8.6`。

新增 `0018-add-player-presence-history.patch`：

- 复用 PalPanel 现有 15 秒监控采样；
- 从官方 REST `/players` 读取在线玩家；
- 按 PlayerUID/SteamID 合并身份并持久记录本次在线、累计在线、最近上线和最近下线；
- 保存最近 20 次完整在线会话；
- 玩家列表与玩家详情直接展示统计；
- REST 暂时不可用时不误判全员下线；
- 长时间中断恢复后最多补记 60 秒；
- 仅当前服务器存档源显示实时历史；
- 使用现有 SQLite KV，不修改 Palworld 存档和数据库 schema。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.12-to-v0.12.13.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.13: add player presence history"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。
预期 Release tag 为 `uitok-stable-v1.3.0-p0.8.6`。
