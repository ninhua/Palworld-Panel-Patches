# Contributing

## 工作流

1. 从 `main` 创建短期分支。
2. 在 `projects/<project>/patches/<upstream-version>/` 中添加补丁。
3. 更新 `manifest.json`。
4. 运行：

```bash
bash common/scripts/validate-repository.sh
```

5. 提交 Pull Request。

## 安全要求

- 不提交管理员密码、Steam 凭据、API Key、存档或玩家个人数据。
- 不使用 `latest` 作为唯一兼容依据。
- 不允许跳过原始文件 SHA-256 校验。
- 安装必须通过 staging 目录完成，再执行原子替换。
- 发生校验失败时必须保留原版程序。
