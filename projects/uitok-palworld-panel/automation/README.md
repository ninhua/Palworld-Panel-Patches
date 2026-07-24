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
→ 选择最高 vMAJOR.MINOR.PATCH
→ 检查显式不兼容列表
→ 查找最高的上一个已发布稳定补丁
→ 校验并准备稳定版派生源轨道
→ 拉取新的官方稳定标签
→ 应用上一个稳定 Release 的合并补丁
→ 将 PatchInfo 重定向到目标稳定版本
→ 重新生成 OpenAPI TypeScript 契约
→ 执行 Go 测试、前端 lint、Vitest、前端构建、嵌入式二进制构建和冒烟测试
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
uitok-stable-v1.3.0-p0.8.1
→ uitok-stable-v1.4.0-p0.8.1
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

## 已知测试上下文漂移

上游稳定版调整 `backend/internal/pallocalize/localize_test.go` 时，旧补丁中的测试 hunk 可能无法直接应用。

构建使用 `apply-source-patch.sh`：

```text
完整补丁可应用
→ 正常应用

只有 pallocalize/localize_test.go 冲突
且补丁内容仍是 ItemIcon / ContainerName 测试
且排除该路径后其余补丁可完整应用
→ 排除旧测试 hunk
→ 生成独立 patch_storage_localize_test.go

任何其他情况
→ 构建失败，不创建 Release
```

该规则不会忽略核心实现冲突，也不会使用 `.rej` 文件继续构建。


## 官方二进制安装基线

稳定补丁 manifest 中的：

```text
files.bin/palpanel.original_sha256
```

必须对应上游正式 GitHub Release 的 Linux 包内 `bin/palpanel`，不得使用本仓库从源码
重新构建的未打补丁二进制代替。`resolve-official-palpanel.sh` 会：

```text
下载上游 Release SHA256SUMS 和 Linux 归档
→ 校验归档 SHA-256
→ 拒绝不安全路径、链接和特殊文件
→ 校验归档内 checksums.txt
→ 执行 palpanel --version 验证目标版本
→ 输出官方二进制和 official-release.json
```

源码重建二进制仍用于编译验证，其 SHA-256 只记录为：

```text
build-metadata.json.rebuilt_original_palpanel_sha256
```

## stable 补丁发布版本

`config.json` 的 `stable_patch_version` 控制本次 stable Release 补丁版本。修复发布资产或
安装契约但功能集合不变时，也必须递增该版本。例如：

```text
uitok-stable-v1.3.0-p0.8.0  # 错误的官方 SHA 基线
uitok-stable-v1.3.0-p0.8.1  # 修正后的重新发布
```

同一 PalPanel 版本下，一键部署选择补丁版本最高的 Release。

## 前端 API 测试响应夹具适配

PalPanel v1.3.0 的 `handleRequest` 仅在模拟响应同时包含 `data` 与 `status` 时将其识别为
AxiosResponse。旧补丁链中的部分 Vitest 用例只返回 `data`，导致响应 envelope 未解包，映射器
收到错误层级并产生 `Unknown Base`、空仓库或空详情等回退值。

构建在应用补丁和重定向版本后执行：

```text
adapt-frontend-api-tests.py
```

该适配器只处理 `frontend/src/**/*.test.ts(x)` 中形如：

```ts
vi.spyOn(apiClient, '...').mockResolvedValue({
  data: ...
})
```

的 Axios spy mock，为其补充 `status: 200`。它不会修改生产 API 代码，也不会修改普通
`vi.fn()` mock；重复执行保持幂等。任何测试仍失败时，Workflow 继续按失败处理，不创建 Release。
