# 平台和工具链矩阵

状态：规划；此表不表示已支持的平台。以下检查仅针对本次执行环境，不代表用户电脑。

| 目标 | 主程序 | 系统组件 | 本次环境检查 | 验收状态 |
| --- | --- | --- | --- | --- |
| Web | Flutter Web | 无 | Flutter/Dart 未安装 | 未验证 |
| Android | Flutter | Kotlin / Glance 或 AppWidget | Flutter/Dart 未安装；Android SDK 未检查 | 未验证 |
| iOS | Flutter | SwiftUI / WidgetKit | 需要 macOS/Xcode 构建环境 | 未验证 |
| macOS | Flutter | SwiftUI / WidgetKit | 需要 macOS/Xcode 构建环境 | 未验证 |
| Windows | Flutter | Windows App SDK Widget Provider | Flutter/Dart 未安装；Windows 构建机未检查 | 未验证 |

当前可用于协议工作的工具：Node.js v24.19.0、npm 11.9.0、Git 2.51.1。下一步在实际构建机记录版本、最低系统版本、架构、编译命令和安装结果。
