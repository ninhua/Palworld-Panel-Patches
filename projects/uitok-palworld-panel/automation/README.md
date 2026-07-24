# Stable release automation

该目录负责在上游 `uitok/palworld-panel` 发布正式稳定版后，自动生成对应的稳定补丁 Release。

## 行为

```text
每天检查一次上游正式 Release
→ 选择最高 vMAJOR.MINOR[.PATCH]
→ 检查显式不兼容列表
→ 检查同名稳定补丁 Release 是否已存在
→ 拉取官方稳定标签
→ 应用当前维护的完整功能补丁链
→ 将 PatchInfo 重定向到目标稳定版本
→ 重新生成 OpenAPI TypeScript 契约
→ 执行 Go 测试、前端构建、嵌入式二进制构建和冒烟测试
→ 生成 manifest、源码包、安装包和 SHA256SUMS
→ 直接创建稳定 GitHub Release
```

不会创建 PR，也不会创建 Issue。任何补丁冲突、测试失败、构建失败或冒烟失败都会使 Workflow 失败；失败时不生成 Release，因此生产启动脚本不会发现可安装版本。

## 调度

Workflow：

```text
.github/workflows/auto-release-uitok-stable.yml
```

Cron：

```text
17 1 * * *
```

即每天执行一次。也可通过 `workflow_dispatch` 手动指定版本。

## 版本匹配

稳定补丁安装按以下字段判断：

```text
compatibility.mode == exact
compatibility.target_version == 当前 PalPanel 稳定版本
compatibility.verified == true
```

`upstream.commit` 只用于源码追踪，不参与运行时安装匹配。

稳定补丁版本从当前维护轨道的功能补丁版本派生：

```text
0.8.0-dev.1 → 0.8.0
```

Release tag 示例：

```text
uitok-stable-v1.3.0-p0.8.0
```

## 明确不兼容

需要人工阻止某个上游版本时，编辑：

```text
incompatible-versions.json
```

示例：

```json
{
  "schema_version": 1,
  "versions": {
    "v1.4.0": "上游删除了存档索引接口，现有补丁无法安全迁移"
  }
}
```

命中后 Workflow 正常跳过，不创建 PR、Issue 或 Release。
