# 贡献指南

欢迎为 Zero Player 贡献代码、文档或反馈。

## 报告问题

- 先查看[常见问题](/guide/faq)并完成相关排查
- 还不能确认是程序问题或需要询问使用方法时，先到 [Discussions](https://github.com/Empty-57/ZeroBit-Player/discussions/categories/general) 交流
- 能够复现的异常使用对应的 [Issue 模板](https://github.com/Empty-57/ZeroBit-Player/issues/new/choose) 提交
- 日志位于程序目录下 `logs` 中，请将完整日志、复现步骤、系统版本和相关样本附在 Issue 中

## 提交代码

1. Fork 并 clone 仓库
2. 功能分支从 main 分出来
3. 按 [构建指南](/dev/build) 完成首次运行
4. 确保 `flutter analyze` 无错误，并运行与改动相关的测试
5. 描述清楚改了什么、为什么改

开发环境搭建见 [构建](/dev/build)。

## 代码约定

- 进行性能和稳定性测试
- 不要提交未经格式化的代码
- 提交代码不得引入新的 warning；对于确实需要忽略的 Clippy / Dart Analyzer 警告，应说明原因
- 统一命名规范
- 不要在 Flutter 层重复实现 Rust 已经提供的核心逻辑，也不要让 Rust 层依赖 UI 状态
- 注释应该解释“为什么”，而不是解释“代码在做什么”，对于公开 API、复杂算法、FFI 接口，要求补充文档注释
- 不要使用已弃用的方法

## 非代码贡献

- 完善文档、修正错别字、补充 FAQ
- 翻译（页面 / 应用内文案）
- 推广 —— 在社交平台分享、加 Star

## 行为准则

保持开放和尊重。讨论聚焦于代码和产品，不欢迎人身攻击。