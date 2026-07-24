# Stable release automation

该目录负责在上游 `uitok/palworld-panel` 发布正式稳定版后，自动生成对应的稳定补丁 Release。

## 派生规则

稳定补丁按以下顺序选择来源：

```text
1. 查找当前补丁仓库中目标版本之前、版本最高的已发布 stable Release
2. 同一上游版本存在多个补丁版本时，选择补丁版本最高者
3. 下载该 Release 的 manifest、build-metadata、SHA256SUMS 和合并补丁
4. 校验 Release tag、target_version、patch_version、exact/verified 与合并补丁 SHA-256
5. 将该合并补丁应用到新的官方稳定版源码
6. 重新定向 PatchInfo、OpenAPI 和构建版本到新版本
7. 完整测试、构建和冒烟通过后发布新 stable Release
```

只有第一次没有任何更早的 stable Release 时，才使用 `config.json` 中的：

```text
bootstrap_source_track
```

当前首次迁移源是旧 dev 补丁轨道。首次稳定 Release 发布后，后续上游稳定版本不再从 dev 轨道派生。

## 行为

```text
每天检查一次上游正式 Release
→ 选择最高 vMAJOR.MINOR[.PATCH]
→ 检查显式不兼容列表
→ 查找最高的上一个已发布稳定补丁
→ 校验并准备稳定版派生源轨道
→ 拉取新的官方稳定标签
→ 应用上一个稳定 Release 的合并补丁
→ 将 PatchInfo 重定向到目标稳定版本
→ 重新生成 OpenAPI TypeScript 契约
→ 执行 Go 测试、前端构建、嵌入式二进制构建和冒烟测试
→ 生成 manifest、derivation、源码包、安装包和 SHA256SUMS
→ 直接创建稳定 GitHub Release
```

不会创建 PR，也不会创建 Issue。任何派生校验、补丁应用、测试、构建或冒烟失败都会使 Workflow 失败；失败时不生成 Release，因此生产启动脚本不会发现可安装版本。

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

迁移到新的上游稳定版但功能集未变化时，补丁功能版本保持不变：

```text
uitok-stable-v1.3.0-p0.8.0
→ uitok-stable-v1.4.0-p0.8.0
```

每个稳定 Release 都包含：

```text
derivation.json
```

用于记录首次迁移源，或上一个稳定 Release tag、目标版本、补丁版本及合并补丁 SHA-256。

## 明确不兼容

需要人工阻止某个上游版本时，编辑：

```text
incompatible-versions.json
```

命中后 Workflow 正常跳过，不创建 PR、Issue 或 Release。
