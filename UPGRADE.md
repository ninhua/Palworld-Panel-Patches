# Upgrade v0.11.2 → v0.11.3

本次升级修复 PalPanel v1.3.0 stable 补丁安装时的官方二进制 SHA-256 不匹配：

```text
当前 SHA-256：fe92a0564f3e5aead26ff61449e804a95cd31df9273bc95c5184b1557c645cec
错误 manifest 期望：040f6d26bc04d505570c39fc8f80c3163289c8e32a7e4fed8d7446a528040c8f
```

旧构建将源码重新编译得到的未打补丁二进制 SHA-256 写入 manifest，但生产环境安装的是
上游 GitHub Release 中的正式二进制。两者不保证逐字节可复现，因此安装器按安全规则拒绝
替换并回滚。

新逻辑：

```text
下载上游正式 Release 的 SHA256SUMS
→ 校验 palpanel_v1.3.0_linux_amd64.tar.gz
→ 安全检查归档路径、文件类型和链接
→ 校验包内 checksums.txt
→ 提取并执行 bin/palpanel --version
→ 将正式二进制 SHA-256 写入 manifest.original_sha256
→ 源码重建 SHA-256 仅写入 build-metadata 供追踪
```

稳定补丁版本提升为：

```text
0.8.1
```

新 Release tag：

```text
uitok-stable-v1.3.0-p0.8.1
```

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.11.2-to-v0.11.3.zip
cp -a Palworld-Panel-Patches-upgrade-v0.11.2-to-v0.11.3/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "fix: verify official PalPanel release binary"
git push origin main
```

然后手动运行：

```text
Auto release uitok stable patch
upstream_version = v1.3.0
```

成功后应生成：

```text
uitok-stable-v1.3.0-p0.8.1
uitok-palworld-panel_stable-v1.3.0_patch-0.8.1_linux-amd64.tar.gz
```

一键部署脚本会在同一 PalPanel 版本下选择补丁版本最高的 `p0.8.1`，不需要修改
`linux-palworld-oneclick.sh` 或 `palpanel-feature-patch.sh`。
