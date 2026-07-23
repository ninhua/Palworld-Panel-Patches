# Palworld Panel Patches

骨架版本：`v0.2.4`

用于维护 Palworld 面板源码补丁、Jiaayu 功能移植记录，以及 Host Wine AIO 兼容接入代码。

## 项目定位

```text
uitok/palworld-panel
    ↓
projects/uitok-palworld-panel/
    实际补丁目标，产出补丁版 palpanel

Jiaayu/palworld-panel
    ↓
ports/jiaayu-features/
    功能参考来源、移植分析和映射记录

你的 Linux/Wine 启动脚本
    ↓
projects/host-wine-aio/
    补丁检测、安装、回滚和运行环境接入
```

`Jiaayu/palworld-panel` 当前不是独立发布目标，因此不放在 `projects/` 下。

## 当前兼容开发目标

```text
实际源码：uitok/palworld-panel v1.2.1
临时目标：v1.2.2 compatibility proxy
目录：projects/uitok-palworld-panel/patches/v1.2.2-compat-v1.2.1/
```

该目录仅用于临时开发验证，不能发布为精确 v1.2.2 补丁。

## 目录

```text
Palworld-Panel-Patches/
├── VERSION
├── CHANGELOG.md
├── LICENSE
├── requirements-ci.txt
├── common/
│   ├── schemas/
│   └── scripts/
├── projects/
│   ├── uitok-palworld-panel/
│   └── host-wine-aio/
├── ports/
│   └── jiaayu-features/
├── templates/
└── .github/workflows/
```

## 设计原则

- 长期分支只保留 `main`。
- 补丁必须绑定上游 tag、commit 和原始文件 SHA-256。
- 没有精确兼容补丁时，不应用旧补丁，也不降级面板。
- 原面板源码补丁与 AIO 运行时兼容逻辑分离。
- Jiaayu 目录只记录移植来源、功能映射和许可证审查。
- 安装必须经过 staging、校验、原子替换和回滚。
- 补丁失败默认不阻断原版面板启动。
- 临时源码别名必须明确标记为 `source-alias`。

## 开发分支

```text
feat/uitok-<feature>
feat/jiaayu-port-<feature>
fix/host-wine-<issue>
chore/<scope>
```

## 本地验证

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```
