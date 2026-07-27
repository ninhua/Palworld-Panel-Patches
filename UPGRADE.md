# Upgrade v0.12.32-hotfix4 → v0.12.34

本次覆盖包同时包含运行时 API 目录和新玩家礼包实际发放修复。基线是当前远程仓库 `v0.12.32-hotfix4`；无需先单独覆盖 v0.12.33。

## 新增补丁

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0036-add-runtime-api-catalog.patch
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0037-fix-starter-gift-paldefender-status-resolution.patch
```

## 新玩家礼包修正

旧 `0033` 在 PalDefender `/v1/pdapi/players` 中只接受 `Status=online` 的记录。但该接口返回已知账户目录，`Status` 不是可靠的在线存在标记，因此正确玩家可能永远保持 `pending`。

修正后：

1. 官方 Palworld REST `/players` 继续作为当前在线玩家的唯一来源；
2. PalDefender 账户列表不再按 `Status` 过滤；
3. 使用归一化后的 `UserId` / `PlayerUID` 解析实际发放目标；
4. PlayerUID 对照忽略连字符，兼容官方紧凑形式与 PalDefender UUID 形式；
5. 已有 `pending` 或旧 `PLAYER_NOT_FOUND` 任务在下一次 15 秒采样自动恢复。

同一账号如果已被旧版本写入“已见玩家”且从未产生任务，无法自动判断它是否是真正老玩家。请用从未进入该 WorldID 的账号复测；已有任务可在发放记录中重置后完成一次离线→上线。

## API 目录

```http
GET /api/catalog
```

该接口位于受认证的 `/api` 路由组，实时返回当前进程注册的全部 API、方法、路径、权限、用途、请求和返回说明。根目录 README 已列出补丁新增或增强接口的使用方法。

## 版本

```text
仓库版本：0.12.34
当前已发布 stable patch：0.8.16
下一 stable patch：0.8.17
预期 Release：uitok-stable-v1.3.0-p0.8.17
```

## 提交前检查

```bash
cd projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source
sha256sum -c SHA256SUMS
cd ../../../..
bash common/scripts/validate-repository.sh
```
