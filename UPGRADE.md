# Upgrade v0.12.0 → v0.12.1

本次升级修复 stable Release 已成功、但仓库 Validate 随后失败的问题。

## 根因

`build-palpanel.sh` 已执行完整前端命令链：

```text
npm ci --no-audit --no-fund
npm run lint
npm run test
npm run build
```

但 `tests/test-relative-output-path.sh` 的 fake npm 仍只接受 `npm ci` 和
`npm run build`，因此在 `npm run lint` 主动报错：

```text
unexpected npm arguments: run lint
```

这是回归测试夹具过期，不是已发布 PalPanel 二进制或补丁功能失败。

## 修复

- fake npm 现在接受并记录完整的 ci/lint/test/build 命令链；
- 测试会校验命令参数和执行顺序，避免以后再次发生夹具漂移；
- 新增 `common/scripts/validate-all.sh`；
- 普通 Validate 与 stable Release 发布前均调用同一个统一校验入口；
- 仓库或回归测试失败时，stable Release 工作流会在版本检测和发布前停止。

## 应用升级

```bash
unzip Palworld-Panel-Patches-upgrade-v0.12.0-to-v0.12.1.zip
cd Palworld-Panel-Patches-upgrade-v0.12.0-to-v0.12.1
bash apply-upgrade.sh /path/to/Palworld-Panel-Patches
```

然后执行：

```bash
cd /path/to/Palworld-Panel-Patches
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
```

已经成功发布的 `uitok-stable-v1.3.0-p0.8.1` 不需要删除或重新构建。本次只修复补丁仓库的验证与发布前置检查，stable patch version 继续保持 `0.8.1`。
