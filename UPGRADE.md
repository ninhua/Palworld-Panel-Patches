# Upgrade v0.12.17 → v0.12.18

本次更新接入联机主机角色到专服 UID 的安全迁移流程，stable patch 目标为 `0.8.8`。

应用增量包后应确认：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch
```

以及 manifest 的 features 中包含：

```json
"host-save-migrator"
```

Release overlay 中另外包含 `bin/palworld-uid-remap`。该 helper 不作为 manifest 的安装前置文件，避免旧安装器因目标文件尚不存在而拒绝升级。

下一次 Release 标签：

```text
uitok-stable-v1.3.0-p0.8.8
```

GitHub Action 需要 Rust toolchain。构建产物中的 `palworld-uid-remap` 必须通过：

```bash
bin/palworld-uid-remap derive-host-uid --steam-id 76561198000000000
```


兼容现有部署脚本：部署脚本无需增加额外复制步骤。完整 overlay 安装会自然复制 helper；若旧部署或热更新只替换 `palpanel`，0.8.8 面板会在首次主机迁移预检时从同版本 Release 包提取 helper，并使用构建时嵌入的 SHA-256 校验。离线环境可提前把 helper 放到面板同目录，或设置：

```bash
PALPANEL_UID_REMAPPER_BIN=/absolute/path/palworld-uid-remap
```

需要使用镜像包时可设置：

```bash
PALPANEL_UID_REMAPPER_PACKAGE_URL=https://mirror.example/uitok-palworld-panel_stable-v1.3.0_patch-0.8.8_linux-amd64.tar.gz
```
