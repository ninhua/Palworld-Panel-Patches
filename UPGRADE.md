# Upgrade v0.12.34-hotfix8 → v0.12.34-hotfix9

本次更新为“下次进入重新发放初始物资”增加明确的取消操作，继续合并在现有 `0038`，不新增补丁编号。

## 使用方式

在“新玩家礼包 → 玩家判定”中：

1. 未标记玩家显示“下次进入视为新玩家”；
2. 已标记、显示 `rearm` 的玩家改为显示“取消下次进入重发”；
3. 点击取消并确认后，`rearm` 标记立即清除。

取消后的行为：

```text
保留 seen 已见基线
不删除现有礼包任务
不创建新的补发/重发任务
下一次离线→上线不会因已取消标记触发发放
```

已经通过“立即完整重发”创建并开始执行的任务不属于待进入标记，取消 `rearm` 不会停止该任务；可在发放记录中继续查看其进度。

## 补丁结构

```text
补丁链：0001–0038
修改补丁：0038-add-starter-gift-debug-console-and-rich-template-indexes.patch
新增补丁编号：无
```

## 应用

在当前 `v0.12.34-hotfix8` 仓库根目录直接覆盖：

```bash
unzip -o Palworld-Panel-Patches-overlay-v0.12.34-hotfix8-to-v0.12.34-hotfix9.zip
bash common/scripts/validate-repository.sh
```

## 版本

```text
仓库版本：0.12.34-hotfix9
当前已发布 stable patch：0.8.17
下一 stable patch：0.8.18
预期 Release：uitok-stable-v1.3.0-p0.8.18
```
