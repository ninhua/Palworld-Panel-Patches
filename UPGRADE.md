# Upgrade v0.12.32-hotfix1 → v0.12.32-hotfix2

本次更新修复覆盖路径错误。

## 原因

上一提交将修改后的 0032 补丁写入了错误位置：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/source/0032-read-starter-gift-template-indexes.patch
```

而 stable 迁移读取的是顶层文件：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/0032-read-starter-gift-template-indexes.patch
```

因此出现：

```text
actual=187e601b329bcdc162ab5b383576e73cfd86eca5e0d167158a5ca9bbd5e9feb4
expected=43fcdfa066ed8d3741220babaca0b6676aeb679f6ddc29593bb574ea64a19232
```

## 修正

本覆盖包直接覆盖正确的顶层 0032 文件，并保留与之匹配的 `SHA256SUMS`。覆盖后应得到：

```text
43fcdfa066ed8d3741220babaca0b6676aeb679f6ddc29593bb574ea64a19232  0032-read-starter-gift-template-indexes.patch
```

上一提交误创建的嵌套文件无法通过普通 ZIP 覆盖删除，需要在提交时删除：

```text
projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source/source/0032-read-starter-gift-template-indexes.patch
```

## 版本

```text
仓库版本：0.12.32-hotfix2
当前已发布 stable patch：0.8.15
下一 stable patch：0.8.16
预期 Release：uitok-stable-v1.3.0-p0.8.16
```
