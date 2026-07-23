# Palworld Panel Patches

骨架版本：`v0.3.0`

用于维护 Palworld 面板源码补丁、Jiaayu 功能移植记录，以及 Host Wine AIO 兼容接入代码。

## 当前开发基线

```text
源码仓库：uitok/palworld-panel
源码分支：dev
兼容目标：面板 v1.2.2
开发阶段：上游源码锁定与构建探测
```

`dev` 是开发源码基线；兼容版本 `v1.2.2` 是运行目标。两者分别记录，不能把分支名称、源码 commit 和运行版本混为一项。

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

## 开发流程

1. 运行 GitHub Actions：`Probe uitok dev source`。
2. 固定 `dev` 当前完整 commit。
3. 下载动作生成的源码快照与分析报告。
4. 根据真实路由和构建入口制作 `patch-info-api` 补丁。
5. 构建原版与补丁版，记录两个 SHA-256。
6. 再接入 Host Wine AIO。

## 本地验证

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```
