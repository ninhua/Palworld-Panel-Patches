# Migration to v0.4.0

现在正式使用：

```text
projects/uitok-palworld-panel/patches/dev-v1.2.2/
```

早期试验目录不再使用：

```text
projects/uitok-palworld-panel/patches/v1.2.2/
projects/uitok-palworld-panel/patches/v1.2.2-compat-v1.2.1/
```

确认其中没有自行添加的文件后，可删除：

```bash
git rm -r   projects/uitok-palworld-panel/patches/v1.2.2   projects/uitok-palworld-panel/patches/v1.2.2-compat-v1.2.1
```
