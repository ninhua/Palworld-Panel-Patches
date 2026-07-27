# 源码补丁维护要点

本文件位于仓库根目录。后续新增或修正 `projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/*.patch` 时必须遵守以下规则。

## 1. 补丁只能基于完整前序链生成

禁止在官方源码、局部夹具、旧 candidate 或只应用部分补丁的工作区上直接生成后续补丁。

正确流程：

1. 从锁定的官方 PalPanel 版本创建干净 Git 工作区；当前稳定轨道为 `uitok/palworld-panel v1.3.0`。
2. 按 `patch-catalog.json` 和文件名字典序应用目标补丁之前的全部必需补丁。
3. 每一项都使用仓库内同一个入口：

   ```bash
   projects/uitok-palworld-panel/automation/apply-source-patch.sh <workspace> <patch>
   ```

4. 确认前序链完成编译检查后再修改源码。
5. 使用该累计工作区生成 `git diff --binary --full-index`，不得手写或伪造 `index <old>..<new>`。
6. 用新 diff 替换对应补丁，重新生成 `source/SHA256SUMS`。

补丁的 old blob 必须等于其实际前置工作区中的目标文件 blob。只验证功能标记、独立 helper 或单个新文件不足以证明补丁可以累计应用。

## 2. 每次必须执行累计迁移检查

提交前至少执行：

```bash
bash common/scripts/validate-repository.sh
```

涉及 PalPanel 源码补丁时，还必须在锁定上游源码上完整执行：

```bash
projects/uitok-palworld-panel/automation/prepare-source-track.sh
```

或运行 stable Workflow 的 migration 阶段。必须确认目标补丁能够在全部前序补丁应用后的工作区上通过：

```bash
git apply --check

go test -run '^$' ./...
```

不得以“单独补丁测试通过”替代累计迁移。

## 3. 同一文件被后续补丁修改时必须重新变基

若补丁修改的文件已经被上游版本或前序补丁改变，必须重新生成该补丁的对应 file section。禁止仅修改 hunk 行号、降低上下文或依赖模糊匹配。

只有确实无法直接重建补丁、且变换语义可以被完整验证时，才允许在 `apply-source-patch.sh` 登记精确重定位规则。重定位规则必须：

- 精确匹配补丁文件和目标 section；
- 校验全部新增、删除内容；
- 对未知差异直接失败；
- 有独立回归测试。

## 4. 覆盖包路径必须以仓库根目录为基准

目录覆盖 ZIP 内第一层必须直接是仓库文件或目录，例如：

```text
VERSION
README.md
projects/uitok-palworld-panel/...
```

禁止出现：

```text
Palworld-Panel-Patches-main/...
projects/.../source/source/...
```

补丁文件只能直接位于：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/*.patch
```

普通 ZIP 不能删除旧文件。需要删除路径时，必须在交付说明中给出明确的 `git rm`，并在验证脚本中拒绝遗留路径。

## 5. SHA-256 必须与实际文件同时交付

修改任何 `.patch` 后必须立即更新：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/SHA256SUMS
```

校验命令：

```bash
cd projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source
sha256sum -c SHA256SUMS
```

覆盖包制作完成后，应在空目录重新解压，并再次执行同一校验，防止只更新校验清单、漏装补丁文件或写入错误层级。

## 6. 新功能补丁的最低回归要求

每个新增补丁必须同时具备：

- 变更文件白名单；
- 实际补丁 SHA-256 校验；
- 锁定上游 preimage 或完整累计工作区应用测试；
- 后端编译或 Go 行为测试；
- 前端 TypeScript/构建检查；
- Release 五文件布局检查；
- 覆盖包重新解压一致性检查。

发现 migration blocked 时，应修正首次失败补丁本身或其精确前置依赖，不要继续叠加依赖失败状态的新功能补丁。

## 7. TypeScript 可选字段必须经过语义编译

前端类型中的 `string | undefined`、`number | undefined` 等可选字段，不得直接传给要求确定类型的 `Map.set`、`Set.add`、`localeCompare` 或其他严格参数。必须先归一化、判空或提供类型安全的回退值。

补丁级 marker/grep 测试只能作为快速回归，不能替代完整候选工作区的 TypeScript 语义编译。stable 候选在发布前必须在全部补丁应用后的前端目录执行项目实际构建命令，例如：

```bash
npm ci
npm run build
```

出现 TypeScript 编译错误时，应新增或修正紧随相关功能补丁之后的纠正补丁，并把该错误对应的可选字段类型写入回归夹具；不得仅通过类型断言 `as string` 掩盖空值。

## 8. 新增或增强 API 必须同步三处契约

任何补丁新增路由、改变权限、扩展 Query/Body 或显著改变返回字段时，必须同时更新：

1. `docs/openapi.yaml`：operation、schema 和 `x-palpanel-permission`；
2. 根目录 `README.md` 的“API 使用说明”：方法、路径、权限、参数、用途和示例；
3. `api-catalog` 的精确描述表；未单独描述的上游接口至少应由路由家族说明覆盖。

提交前必须确认 `GET /api/catalog` 从 `router.Routes()` 读取运行时路由，不能维护一份与实际路由分离的静态路径总表。路由删除或改名时必须同步删除旧说明。

## 9. 外部接口状态字段不得凭名称推断语义

第三方接口中的 `Status`、`State`、`Online` 等字段必须按其实际契约解释，不得仅凭字段名称作为运行门禁。跨接口关联时应明确一个权威来源：本项目的新玩家礼包以官方 Palworld REST `/players` 决定当前在线集合，PalDefender `/v1/pdapi/players` 只负责把已确认在线的身份映射为可写入的 `UserId` / `PlayerUID`。

涉及外部身份映射的补丁至少要覆盖：空状态、非预期状态、大小写、格式差异（例如 UUID 连字符）、无关账户和延迟出现。测试必须执行实际修补后的 helper，而不是只 grep 标记。

