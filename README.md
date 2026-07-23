# Palworld Panel Patches

骨架版本：`v0.4.0`

用于维护 Palworld 面板源码补丁、Jiaayu 功能移植记录，以及 Host Wine AIO 兼容接入代码。

## 当前开发基线

```text
源码仓库：uitok/palworld-panel
源码分支：dev
源码提交：5e3c0bce9d33091b3261f82b3e4da062fc35a8a1
兼容目标：v1.2.2
补丁版本：0.1.0-dev.1
首个功能：patch-info-api
```

## 当前真实补丁

```text
projects/uitok-palworld-panel/patches/dev-v1.2.2/
├── upstream-lock.json
├── manifest.template.json
├── source/
│   ├── 0001-add-patch-info-api.patch
│   └── SHA256SUMS
├── build/
│   ├── build.sh
│   └── build-palpanel.sh
├── tests/
│   └── smoke.sh
├── LICENSE
└── LICENSE-NOTICE.md
```

补丁新增公开接口：

```http
GET /api/patch/info
```

该接口返回上游仓库、源码分支、源码 commit、兼容目标、补丁版本、功能列表和构建信息。

## 构建

在 GitHub 仓库中运行：

```text
Actions
→ Build uitok dev patch
→ Run workflow
```

成功后下载：

```text
uitok-dev-v1.2.2-patch-0.1.0-dev.1-5e3c0bce9d33
```

Artifact 包含：

- 原版和补丁版二进制 SHA-256；
- 可安装 overlay；
- 最终 `manifest.json`；
- 对应源码 patch；
- 完整补丁后源码归档；
- GPL-3.0 许可证；
- API 冒烟测试结果。

## 本地仓库验证

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```
