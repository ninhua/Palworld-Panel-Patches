# Upgrade v0.10.1 → v0.10.2

本次升级新增：

```text
0011-allow-http-service-endpoints.patch
```

该补丁将 AstrBot 双向连接、WebDAV、AI 翻译 Base URL、可配置上游/下载地址和公共远程 Mod ZIP 从“部分场景强制 HTTPS”调整为接受 HTTP 或 HTTPS。

安全校验仍保留：

- URL 必须为绝对 HTTP(S) 地址；
- 禁止不支持的协议；
- WebDAV 禁止嵌入凭据、查询参数、片段和不安全远程目录；
- Mod 下载仍拒绝凭据 URL、非公网目标、危险重定向和超限文件；
- HTTP 明文传输风险由部署者自行承担。

覆盖升级：

```bash
unzip Palworld-Panel-Patches-upgrade-v0.10.1-to-v0.10.2.zip
cp -a Palworld-Panel-Patches-upgrade-v0.10.1-to-v0.10.2/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "feat: allow HTTP service endpoints"
git push origin main
```

发布契约：

```text
补丁版本：0.8.0-dev.1
Release tag：uitok-dev-v1.2.2-p0.8.0-dev.1
Artifact：uitok-dev-v1.2.2-patch-0.8.0-dev.1-5e3c0bce9d33
```

新增顶级 feature：`insecure-endpoint-support`。启动脚本继续按最高兼容 dev 补丁自动选择；现有必需 feature 使用包含关系校验时无需修改。
