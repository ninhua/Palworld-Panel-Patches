# Upgrade v0.4.1 → v0.4.2

覆盖仓库：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.4.1-to-v0.4.2/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add .
git commit -m "feat: publish patch channel and host-wine integration"
git push origin main
```

先确认：

```text
Actions → Validate repository
Repository validation passed.
Relative output path regression test passed.
```

再发布固定预发布：

```text
Actions → Release uitok dev patch → Run workflow
```

发布成功后应出现 Release：

```text
uitok-dev-v1.2.2-p0.1.0-dev.1
```

最后将：

```text
projects/host-wine-aio/scripts/linux-palworld-oneclick-v1.0.40.sh
```

复制到：

```text
/home/container/linux-palworld-oneclick.sh
```

并赋权：

```bash
chmod +x /home/container/linux-palworld-oneclick.sh
```
