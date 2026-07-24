# Stable patch migration automation

该目录维护 `uitok/palworld-panel` 正式 Release 的补丁迁移、验证和发布。

## 状态机

```text
detected
→ workspace-created
→ patches-imported
→ testing
├─ blocked
└─ merged
   → releasable
   → released
```

工作区文件：

```text
candidate-vX.Y.Z/
├── workspace.json
├── manifest.template.json
├── derivation.json
├── compatibility-report.json
├── source-chain/
├── active-source/
├── merged/
└── reports/
```

`source-chain` 保留导入的完整链；`active-source` 只包含进入最终构建的补丁；`merged` 是 clean-room 复验的唯一输入。

## 上游更新流程

1. `select-latest-version.py` 选择最高正式 tag。
2. `select-previous-stable-release.py` 只选择目标版本之前最新的 verified stable Release。
3. `prepare-source-track.sh` 从新版源码包内的 `.palpatch/source-track` 导入补丁链；首次 stable 或 legacy 迁移才使用 bootstrap/旧 merged patch。
4. `migrate-patch-workspace.py` 按字典序逐补丁处理，记录：
   - `compatible`
   - `adapted`
   - `incompatible`
   - `blocked`
   - `superseded`
   补丁可通过 `patch-catalog.json.validation_checkpoint` 延迟累计编译。逐补丁应用状态仍独立记录，但临时不完整的实现不会在后置纠正补丁到达前被错误回滚。
5. `build-stable-release.sh` 生成 merged patch，并在全新的官方源码副本上仅应用该 merged patch。
6. clean-room 完整执行：gofmt、OpenAPI 生成、Go 测试、前端 lint/Vitest/build、Linux amd64 构建、官方二进制校验和 `/api/patch/info` smoke test。
7. `persist-workspace.sh`：
   - 失败 candidate 写入 `migration/vX.Y.Z`；
   - 成功 stable 写入 main 的 `stable-vX.Y.Z`。
8. GitHub Release 使用显式五文件白名单。

## 发布阻断

以下任一条件成立时禁止发布：

- 必需补丁或上一个 stable 已有功能不可用；
- 补丁 SHA-256 不匹配；
- 依赖补丁失败；
- merged patch 无法在干净官方源码应用；
- Go、前端、构建或 smoke test 失败；
- manifest、运行时 feature 或 Release 文件白名单不一致。

失败不会创建 PR、Issue 或 Release。

## Axios 测试响应适配

PalPanel v1.3.0 仅在模拟响应同时包含 `data` 与顶层 `status` 时将对象识别为 AxiosResponse。

`adapt-frontend-api-tests.py`：

- 解析 `apiClient` spy 的对象字面量边界；
- 区分顶层与嵌套 `status`；
- 只为缺失顶层 `status` 的 mock 补充 `status: 200`；
- 清理旧适配器紧邻 `data` 注入的重复默认状态；
- 对无法安全修复的重复属性直接失败；
- 重复执行保持幂等。

## Release 资产

Release 顶层固定为：

```text
binary package
source package
manifest.json
compatibility-report.json
SHA256SUMS
```

完整 source-chain、merged patch、workspace、derivation、build metadata、official-release metadata 和日志保留在包内。


## 编译检查点

源补丁链按顺序累计应用。`validation_checkpoint=false` 表示当前补丁不能单独代表可编译状态；迁移器保留其源码变化，直到后续 `validation_checkpoint=true` 补丁到达后对整组执行 Go compile-only 和前端 lint。

当前分组：

```text
0008 + 0009 + 0010
0011 + 0012
```

检查点只用于避免错误的中间态失败。最终 merged patch 仍在全新官方源码上执行完整 clean-room 测试。

## SHA256SUMS

`release-checksums.py` 是生成端和消费端的统一解析器。它兼容 GNU `sha256sum` 的文本/二进制标记和 `./` 前缀，严格拒绝重复名称、路径越界、缺失资产和哈希不匹配。Release 顶层校验表只在四个非校验资产全部定稿后生成。


## 无变更目标

补丁应用成功但最终没有源码差异时，各补丁标记为 `superseded`，candidate 状态写为 `no-change`。Workflow 持久化审计工作区后以 `no-release-needed` 成功结束，不生成空 merged patch 或空 Release。
