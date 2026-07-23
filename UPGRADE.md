# Upgrade v0.2.4 → v0.3.0

覆盖到仓库根目录：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.2.4-to-v0.3.0/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add .
git commit -m "feat: add uitok dev source probe"
git push origin main
```

随后进入 GitHub 仓库：

```text
Actions
→ Probe uitok dev source
→ Run workflow
→ upstream_ref 保持 dev
```

运行结束后下载：

```text
uitok-dev-probe-<commit前12位>.zip
```

Artifact 中包含：

- `uitok-palworld-panel-dev-<sha>-source.tar.gz`
- `upstream-lock.generated.json`
- `routing-candidates.txt`
- `api-candidates.txt`
- `entry-candidates.txt`
- `static-embed-candidates.txt`
- `auth-candidates.txt`
- `go-list.txt`
- `go-test.txt`
- `tree.txt`
- `SHA256SUMS`
