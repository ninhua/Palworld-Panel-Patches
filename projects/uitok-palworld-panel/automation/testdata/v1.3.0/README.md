# PalPanel v1.3.0 固定上游夹具

该目录只保存补丁可应用性测试所需的最小上游文件。

当前文件：

```text
frontend/src/pages/Pals.tsx
```

来源：`uitok/palworld-panel` tag `v1.3.0`。

Git blob：

```text
adc7c4d80073b33439a805475fc62ec8567d8b00
```

夹具不得叠加自定义补丁或格式化修改。测试会使用 `git hash-object` 锁定该 blob，并将 `0034-add-pal-inventory-advanced-filters.patch` 的 Pals.tsx section 直接应用到该文件。
