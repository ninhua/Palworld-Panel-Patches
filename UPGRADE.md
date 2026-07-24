# Upgrade v0.11.3 → v0.11.4

Run #4 在前端 Vitest 阶段失败：

```text
src/api/bases.test.ts
expected: 北境制造中心
received: Unknown Base
```

根因是测试夹具兼容性，而不是生产端基地自定义名称逻辑被跳过。旧补丁测试使用：

```ts
vi.spyOn(apiClient, 'put').mockResolvedValue({
  data: { ok: true, data: { ... } },
})
```

PalPanel v1.3.0 的 `handleRequest` 只有在对象同时含有 `data` 和 `status` 时才按 AxiosResponse
解包。缺少 `status` 后，映射器收到整个模拟对象而不是 envelope 的 `data`，`mapBase` 找不到
`name`，因此返回 `Unknown Base`。

v0.11.4 在稳定源码构建阶段运行 `adapt-frontend-api-tests.py`，把补丁新增 API 测试的旧式
Axios spy mock 转换为：

```ts
vi.spyOn(apiClient, 'put').mockResolvedValue({
  status: 200,
  data: { ok: true, data: { ... } },
})
```

适配范围包括 `frontend/src/**/*.test.ts(x)` 中的 `apiClient` spy，因此基地仓库、玩家备注、
公会详情、基地工作帕鲁和饲料箱等同类测试不会在下一轮继续逐个失败。生产 API 代码不被修改。

稳定补丁版本仍为：

```text
0.8.1
```

Run #4 在 Release 发布步骤之前失败，`uitok-stable-v1.3.0-p0.8.1` 尚未创建，所以不需要提升
为 `0.8.2`。

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.11.3-to-v0.11.4.zip
cp -a Palworld-Panel-Patches-upgrade-v0.11.3-to-v0.11.4/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后重新手动运行：

```text
Auto release uitok stable patch
upstream_version = v1.3.0
```

成功后仍应生成：

```text
uitok-stable-v1.3.0-p0.8.1
uitok-palworld-panel_stable-v1.3.0_patch-0.8.1_linux-amd64.tar.gz
```
