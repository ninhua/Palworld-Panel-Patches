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
