# 平台和工具链矩阵

状态：主程序模拟快照原型已完成 CI 构建；此表不表示已在用户设备上安装或支持原生组件。构建记录来自 GitHub Actions，不能代表真机验收。

| 目标 | 主程序 | 系统组件 | 本次环境检查 | 验收状态 |
| --- | --- | --- | --- | --- |
| Web | Flutter Web | 无 | Ubuntu CI：`flutter build web` 成功 | 构建通过；浏览器验收待做 |
| Android | Flutter | Kotlin / Glance 或 AppWidget | Ubuntu CI：`flutter build apk --debug` 成功，保存调试 APK | 构建通过；设备安装与组件待做 |
| iOS | Flutter | SwiftUI / WidgetKit | macOS CI：`flutter build ios --simulator --debug` 成功 | 模拟器构建通过；设备签名安装与组件待做 |
| macOS | Flutter | SwiftUI / WidgetKit | macOS CI：`flutter build macos --debug` 成功 | 构建通过；设备安装与组件待做 |
| Windows | Flutter | Windows App SDK Widget Provider | Windows CI：`flutter build windows` 成功，保存程序目录 | 构建通过；设备安装与组件待做 |

首次构建记录：Web 工作流 run 35728974477；原生工作流 run 35729527097（2026-09-22）。Android 和 Windows 产物在该工作流页面的 Artifacts 中，仅保留 7 天；均为演示程序，不能用于发布。CI 从 Flutter stable 分支取 SDK，目前尚未固定 SDK 提交版本。下一步锁定工具链与各平台最低系统版本，在实际设备上记录安装、启动、离线缓存、点击行为及原生组件结果。
