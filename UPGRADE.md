# Upgrade v0.12.x → v0.12.3

本次升级修正活动维护轨道仍依赖 `dev-v1.2.2` 的问题。

## 结果

```text
active source track: projects/uitok-palworld-panel/patches/candidate-v1.3.0
target version: v1.3.0
source mode: self-contained
historical dev-v1.2.2: archive only
```

升级脚本会把现有历史轨道中的 `source/`、`build/`、许可文件复制到
`candidate-v1.3.0`，然后写入 v1.3.0 candidate manifest 和 track metadata。
旧 dev workflows 会被删除。

## 应用

```bash
unzip Palworld-Panel-Patches-upgrade-v0.12.x-to-v0.12.3.zip
cd Palworld-Panel-Patches-upgrade-v0.12.x-to-v0.12.3
bash apply-upgrade.sh /path/to/Palworld-Panel-Patches
```

## 验证

```bash
cd /path/to/Palworld-Panel-Patches
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh
```
