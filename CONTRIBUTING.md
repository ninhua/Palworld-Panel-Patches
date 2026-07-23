# Contributing

## 补丁目标

当前可发布补丁目标：

- `projects/uitok-palworld-panel/`
- `projects/host-wine-aio/`

`ports/jiaayu-features/` 仅用于功能来源研究和移植记录。

## 工作流

1. 从 `main` 创建短期分支。
2. 明确修改属于源码补丁、功能移植还是 AIO 兼容接入。
3. 更新对应 manifest 或 feature port 记录。
4. 运行：

```bash
python3 -m pip install -r requirements-ci.txt
bash common/scripts/validate-repository.sh
```

5. 提交 Pull Request。

## 安全要求

- 不提交管理员密码、Steam 凭据、API Key、存档或玩家个人数据。
- 不使用 `latest` 作为唯一兼容依据。
- 不跳过原始文件 SHA-256 校验。
- 安装必须通过 staging 目录完成。
- 补丁失败时必须保留原版程序。
- 移植第三方代码前必须检查许可证并保留必要版权声明。
