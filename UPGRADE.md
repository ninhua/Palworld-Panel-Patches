# Upgrade v0.6.3 → v0.7.0

本次新增独立顶级功能 `player-notes`：在玩家详情中保存管理备注与标签，并支持列表展示和搜索。数据只写入 PalPanel SQLite KV，不修改 Palworld 玩家存档。

## 覆盖升级

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.6.3-to-v0.7.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后先运行 Build，再运行 Release。

```text
补丁版本：0.4.0-dev.1
Release tag：uitok-dev-v1.2.2-p0.4.0-dev.1
新增 feature：player-notes
```

部署脚本若已按当前 PalPanel 版本自动选择最高兼容 dev 补丁，并以 required-features 子集方式验收，则不需要修改下载或安装模块。只有需要强制要求 `player-notes` 存在时，才将它加入启动脚本的必需 feature 列表。
