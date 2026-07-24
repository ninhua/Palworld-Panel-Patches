# Upgrade v0.11.5 → v0.12.0

本次升级重构 PalPanel stable 补丁更新链路，并修复 Run #5 的 TypeScript `TS1117`。

## Run #5 根因

旧适配器在 `vi.spyOn(apiClient, ...).mockResolvedValue({...})` 的 `data` 前直接插入：

```ts
status: 200,
```

部分 PalPanel v1.3.0 上游测试已经在同一对象后部定义了顶层 `status`，因此出现重复属性。

v0.12.0 会解析 mock 对象的顶层属性：

- 已有顶层 `status`：不插入；
- 只有嵌套业务字段 `status`：仍补充 Axios 顶层 `status`；
- 检测到旧适配器紧邻 `data` 插入的重复 `status: 200`：删除注入项，保留上游状态码；
- 无法安全判断的重复属性：在构建前明确失败，不交给 TypeScript 输出一批 TS1117。

## 新更新链路

```text
检测官方 stable tag
→ 创建 candidate-vX.Y.Z 工作区
→ 从最新更旧 stable Release 导入补丁链
→ 逐补丁应用和编译检测
→ 标记 compatible/adapted/incompatible/blocked
→ 生成 active-source 和 merged patch
→ 在全新官方源码上只应用 merged patch
→ 完整测试、构建和 smoke test
→ 固化 stable-vX.Y.Z
→ 发布五文件 Release
```

失败时：

- 不创建 Release；
- 不创建 PR 或 Issue；
- candidate 工作区及兼容报告写入 `migration/vX.Y.Z` 分支；
- main 和上一稳定 Release 不被覆盖。

成功时 Release 顶层只有：

```text
uitok-palworld-panel_stable-vX.Y.Z_patch-P_linux-amd64.tar.gz
uitok-palworld-panel_stable-vX.Y.Z_patch-P_source.tar.gz
manifest.json
compatibility-report.json
SHA256SUMS
```

## 覆盖升级

```bash
unzip Palworld-Panel-Patches-upgrade-v0.11.5-to-v0.12.0.zip
cp -a Palworld-Panel-Patches-upgrade-v0.11.5-to-v0.12.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后重新运行：

```text
Auto release uitok stable patch
upstream_version = v1.3.0
```

Run #5 未创建 `uitok-stable-v1.3.0-p0.8.1`，因此当前 stable patch version 继续使用 `0.8.1`。
