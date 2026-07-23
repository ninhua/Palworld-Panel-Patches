# Upgrade v0.6.1 → v0.6.2

本次修复基地仓库接口返回空列表的问题。实际基地箱子常被存档索引标记为 `map_object`，并通过基地记录的 `containers` 数组关联；旧接口只检查 `owner_type == base`，因此遗漏这些容器。

## 覆盖升级

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.6.1-to-v0.6.2/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交后先运行 Build，再运行 Release。

```text
补丁版本：0.3.1-dev.1
Release tag：uitok-dev-v1.2.2-p0.3.1-dev.1
```

部署脚本需要把开发通道映射从 `0.3.0-dev.1` 更新到 `0.3.1-dev.1`，并重新读取新 Release 的安装包和二进制 SHA-256。
