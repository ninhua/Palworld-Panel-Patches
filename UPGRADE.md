# Upgrade v0.4.2 → v0.5.0

覆盖仓库：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.4.2-to-v0.5.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches
```

验证：

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

提交：

```bash
git add .
git commit -m "feat: add persistent base custom names"
git push origin main
```

构建：

```text
Actions → Build uitok dev patch → Run workflow
```

发布：

```text
Actions → Release uitok dev patch → Run workflow
```

新标签：

```text
uitok-dev-v1.2.2-p0.2.0-dev.1
```

此版本不会修改或替换旧的 `0.1.0-dev.1` Release。
一键部署脚本应在新 Release 资产实际存在并验证后，再由其维护流程更新固定标签和期望字段。
