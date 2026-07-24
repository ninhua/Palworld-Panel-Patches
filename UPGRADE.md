# Upgrade v0.12.11 → v0.12.12

本增量包增加操作审计响应详情弹窗，并将 stable patch version 提升到 `0.8.5`。

新增 `0017-add-audit-log-response-detail-dialog.patch`：

- 点击桌面操作审计表格行或移动端卡片查看完整响应；
- 显示记录 ID、时间、操作者、角色、动作、对象、状态和来源 IP；
- 完整响应继续读取后端已脱敏的 `message` 字段，JSON 内容自动格式化；
- 支持 Enter/空格打开、Esc 或遮罩关闭；
- 支持复制响应，并兼容非 HTTPS 面板页面；
- 不记录未过滤的完整 HTTP 响应体，不修改审计数据库结构。

## 覆盖

```bash
cd /path/to/Palworld-Panel-Patches
unzip -o Palworld-Panel-Patches-overlay-v0.12.11-to-v0.12.12.zip -d .
```

## 验证与提交

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-all.sh

git add -A
git commit -m "v0.12.12: add audit response detail dialog"
git push origin main
```

随后运行 `Auto release uitok stable patch`，目标版本填写 `v1.3.0`。
预期 Release tag 为 `uitok-stable-v1.3.0-p0.8.5`。
