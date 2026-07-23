# Upgrade v0.6.2 → v0.6.3

本次完善现有 `base-storage-browser`：显示容器类型/名称和本地物品图标，不增加新的顶级 feature。

## 覆盖升级

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.6.2-to-v0.6.3/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后先运行 Build，再运行 Release。

```text
补丁版本：0.3.2-dev.1
Release tag：uitok-dev-v1.2.2-p0.3.2-dev.1
```

部署脚本若已按当前 PalPanel 版本自动选择最高兼容 dev 补丁，并以 required-features 子集方式验收，则不需要修改脚本代码。新 Release 的 tag、manifest、SHA256SUMS 和包结构必须继续符合现有规则。
