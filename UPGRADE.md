# Upgrade v0.12.14 → v0.12.15

本增量修复操作审计响应详情弹窗只显示空白大框的问题。stable patch version 继续使用 `0.8.6`，并保留 v0.12.14 的 GitHub API 限额修复。

新增 `0020-fix-audit-response-dialog-portal.patch`：

- 将响应详情通过 React Portal 挂载到 `document.body`；
- 避免 `#app-main` 的滚动容器、`isolation` 和页面进入动画 `transform` 改变 fixed 弹窗的包含块与堆叠上下文；
- 复用面板现有弹窗背景与面板样式；
- 保持记录元数据、完整响应、JSON 格式化、复制和键盘关闭行为不变；
- 为响应区域增加稳定的最小高度和移动端动态视口高度限制。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.14-to-v0.12.15.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.15: fix audit response dialog portal"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。
预期 Release tag 仍为 `uitok-stable-v1.3.0-p0.8.6`。
