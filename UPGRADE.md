# Upgrade v0.4.0 → v0.4.1

覆盖仓库根目录：

```bash
cp -a Palworld-Panel-Patches-upgrade-v0.4.0-to-v0.4.1/. /path/to/Palworld-Panel-Patches/
cd /path/to/Palworld-Panel-Patches

git add .
git commit -m "fix: resolve palpanel output path absolutely"
git push origin main
```

修复的错误：

```text
chmod: cannot access '.work/output/work/original-palpanel': No such file or directory
```

根因：

```text
build.sh 传入相对路径 .work/output/work/original-palpanel
build-palpanel.sh 在 backend/ 目录执行 go build
go build -o 将该相对路径按 backend/ 解析
返回调用目录后 chmod 使用的是另一条路径
```

修复后：

```text
.work/output/work/original-palpanel
    ↓ realpath -m
/home/runner/work/.../.work/output/work/original-palpanel
    ↓
go build -o 使用绝对路径
    ↓
chmod、SHA-256、打包使用同一文件
```

推送后先确认：

```text
Actions → Validate repository
Repository validation passed.
Relative output path regression test passed.
```

随后重新运行：

```text
Actions → Build uitok dev patch
```
