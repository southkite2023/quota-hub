# macOS 本地凭据（3.0.0+20）

## 保存位置与保护范围

使用 path_provider 的 getApplicationSupportDirectory() 返回的应用支持目录，其 credentials 子目录下分别保存 accounts.json、identity.json、settings.json。它位于用户数据目录，不能写入 Astracct.app、DMG、更新缓存或源码目录。

文件格式为 version=1、values=键值映射。macOS 目录权限 0700、文件权限 0600；值为明文，不额外加密，不把解密密钥藏进同目录。仅限制其他系统用户，同一系统用户的程序仍可能读取。应用锁保护界面访问，不能替代文件加密。Android/Windows 保持原有系统凭据存储，Web 不引入此文件存储。

## 旧数据迁移

首次读取本地尚不存在的键时，从原 service 的登录钥匙串读取；余额账户、统一登录和应用锁策略分别迁移。系统可能在这一阶段要求授权一次。读取失败时向调用方报错，不创建空文件、不解锁或覆盖账户。

成功后原子保存；后续读取不再访问该键的钥匙串。新写入直接保存本地，不先读取钥匙串。删除以 null 标记保留在 values 中，防止退出登录后再次导入旧会话。原钥匙串项不删除，用于旧版本回退；旧版看到的账户信息可能停留在迁移时。登录会话的服务端退出行为保持不变。

请勿手动删除凭据文件来清理更新缓存；删除文件会重新触发迁移。迁移完成后，更新应用只替换程序文件，保留用户数据目录。

## 写入及失败行为

临时文件先设 0600，再写入并 flush，最后在同目录原子替换目标；进程内按路径排队保存，避免多个存储实例丢失修改。拒绝符号链接、损坏 JSON、未知版本或非字符串/非 null 值。失败时保留原文件，调用方不得显示保存成功。队列不提供跨进程并发事务。

## 实现参考

参考 OpenClaw 的本地凭据与文件权限思路，独立实现 Flutter 平台适配；没有复制其业务源码。

- https://github.com/openclaw/openclaw/blob/main/docs/start/wizard-cli-reference.md
- https://github.com/openclaw/openclaw/blob/main/docs/gateway/security/secrets-and-storage.md
- https://github.com/chen08209/FlClash （UI 结构参考，独立实现导航、主题和卡片，未引入代理功能或项目资源）

## 验证

本地文件迁移一次、迁移拒绝不覆盖、重启恢复、删除不复活、并发实例保存、0600/0700 权限、损坏文件及符号链接拒绝测试通过。真实用户旧钥匙串的系统授权及原生应用迁移仍需安装包验收。
