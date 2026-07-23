# Upgrade v0.8.0 → v0.9.0

本次新增独立顶级功能 `base-worker-browser`：基地页面可以查看工作帕鲁的种类、昵称、等级、性别、Rank、状态、远征状态和被动词条，并提供统计与搜索。全部数据只读，不修改 Palworld 存档。

## 覆盖升级

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.8.0-to-v0.9.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后先运行 Build，再运行 Release。

```text
补丁版本：0.6.0-dev.1
Release tag：uitok-dev-v1.2.2-p0.6.0-dev.1
新增 feature：base-worker-browser
```

部署脚本若已按当前 PalPanel 版本自动选择最高兼容 dev 补丁，并以 required-features 子集方式验收，则不需要修改下载或安装模块。只有需要强制要求 `base-worker-browser` 存在时，才将它加入启动脚本的必需 feature 列表。
