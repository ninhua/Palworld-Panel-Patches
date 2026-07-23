# Upgrade v0.10.0 → v0.10.1

本次是构建修复，不新增功能，也不提升功能补丁版本。`0008-add-base-worker-browser.patch` 之前漏掉了两个新 Go 文件，导致 Release 编译报错：

```text
s.getSaveBaseWorkers undefined (type Server has no field or method getSaveBaseWorkers)
```

`v0.10.1` 新增 `0010-fix-missing-base-worker-handler.patch`，正式补入：

```text
backend/internal/api/base_workers.go
backend/internal/api/base_workers_test.go
```

## 覆盖升级

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.10.0-to-v0.10.1/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后重新运行 Build；Build 通过后再运行 Release。

```text
补丁版本：0.7.0-dev.1
Release tag：uitok-dev-v1.2.2-p0.7.0-dev.1
features：不变
```

失败的 Release 没有创建不可变标签，因此无需修改功能补丁版本。启动脚本无需更新。
