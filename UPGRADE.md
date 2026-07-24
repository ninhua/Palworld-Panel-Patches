# Upgrade v0.10.2 → v0.10.3

本次升级新增：

```text
0012-restore-ai-translation-net-import.patch
```

修复原因：`0011-allow-http-service-endpoints.patch` 放宽 AI 翻译 Base URL 协议限制时删除了 Go `net` 导入，但 `classifyProviderRequestError` 仍使用 `net.Error` 判断超时，导致 Build/Release 报错：

```text
internal/aitranslation/service.go:791:13: undefined: net
```

本修复只恢复 `import "net"`，不改变接口、运行行为、feature 或补丁版本。

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.10.2-to-v0.10.3.zip
cp -a Palworld-Panel-Patches-upgrade-v0.10.2-to-v0.10.3/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "fix: restore AI translation net import"
git push origin main
```

发布契约保持：

```text
补丁版本：0.8.0-dev.1
Release tag：uitok-dev-v1.2.2-p0.8.0-dev.1
Artifact：uitok-dev-v1.2.2-patch-0.8.0-dev.1-5e3c0bce9d33
```

失败的 Build/Release 未创建正式 Release，因此无需提升功能补丁版本。启动脚本无需更新。
