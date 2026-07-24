# Upgrade v0.11.4 → v0.11.5

本次升级同时处理 Run #5、PalPanel v1.3.0 维护基线和 Release 资产数量问题。

## Run #5 修复

旧适配器看到：

```ts
vi.spyOn(apiClient, 'get').mockResolvedValue({
  data: {...},
  status: 200,
})
```

仍会在 `data` 前插入另一个 `status: 200`，最终触发：

```text
TS1117: An object literal cannot have multiple properties with the same name
```

新适配器解析 mock 对象的顶层属性：

- 有顶层 `data`、没有顶层 `status`：补充 `status: 200`；
- 已有顶层 `status`：不修改，无论它在 `data` 前还是后；
- 仅 `data` 内部存在嵌套 `status`：仍补充 Axios 顶层 `status`；
- 重复运行：不产生任何额外修改。

## v1.3.0 维护轨道

当前配置改为：

```text
maintenance_target_version = v1.3.0
bootstrap_source_track = projects/uitok-palworld-panel/patches/candidate-v1.3.0
```

`candidate-v1.3.0` 显式代表当前维护目标。它继承旧 `dev-v1.2.2` 历史补丁链，但 Actions
始终把补丁应用到官方 PalPanel `v1.3.0` tag 上。完整测试通过前，该目录仍是 candidate，
不得视为 exact/verified stable。

## Release 精简

不再把以下文件逐个上传到 Release 顶层：

```text
0001-*.patch
0002-*.patch
...
PATCH-SHA256SUMS
```

完整源补丁链仍在安装包的：

```text
source/source-chain/
```

以及完整 patched source 包中。Release 顶层继续保留跨版本派生所需的合并补丁、manifest、
build metadata、SHA256SUMS 和安装/源码归档。

## 覆盖升级

```bash
unzip Palworld-Panel-Patches-upgrade-v0.11.4-to-v0.11.5.zip
cp -a Palworld-Panel-Patches-upgrade-v0.11.4-to-v0.11.5/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后重新运行：

```text
Auto release uitok stable patch
upstream_version = v1.3.0
```

Run #5 没有创建 `p0.8.1` Release，因此稳定补丁版本继续使用 `0.8.1`。成功后预期生成：

```text
uitok-stable-v1.3.0-p0.8.1
uitok-palworld-panel_stable-v1.3.0_patch-0.8.1_linux-amd64.tar.gz
```
