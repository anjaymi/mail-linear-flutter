# 项目参考说明

本项目不是直接 fork 或复制某一个开源项目，而是在本地桌面邮箱管理工具的目标下，参考了若干开源项目的产品思路、功能边界和接口方向，并重新实现为当前的架构：

- Flutter 桌面端界面
- Rust 本地 sidecar API
- SQLite 本地缓存
- Outlook 令牌账号收件
- ClawEmail 绑定、子邮箱同步和收件

## 参考项目

### Maishan-Inc / Microsoft-Email-Manager

链接：https://github.com/Maishan-Inc/Microsoft-Email-Manager

参考方向：

- Microsoft / Outlook 邮箱账号管理
- 批量邮箱管理工具的基础产品形态
- 邮件收取与账号状态管理思路

当前实现说明：

- 本项目没有直接复用该项目代码。
- Outlook 账号导入、缓存、收件、桌面端交互均在本项目内重新实现。

### aa1125573296-svg / Outlook-Mail-Manager

链接：https://github.com/aa1125573296-svg/Outlook-Mail-Manager

参考方向：

- Outlook 令牌账号导入格式
- 批量账号管理流程
- 邮件管理工具的基础功能组织

当前实现说明：

- 本项目早期 Node 服务和当前 Rust sidecar 均为本项目内实现。
- 当前桌面版已经转为 Flutter + Rust sidecar 的独立结构。

### fengyuanluo / firemail

链接：https://github.com/fengyuanluo/firemail

参考方向：

- 邮件客户端的阅读体验
- 收件箱列表、邮件阅读区和操作区的产品布局
- 轻量邮箱工具的交互组织方式

当前实现说明：

- 本项目 UI 已按桌面软件重新设计，并没有直接使用该项目界面代码。
- 邮件页、账号页、工作台和设置页均为本项目自定义实现。

### WangXingFan / ClawEmail

链接：https://github.com/WangXingFan/ClawEmail

参考方向：

- ClawEmail 绑定流程
- 子邮箱管理
- Claw API / Coremail proxy 收件方向

当前实现说明：

- 本项目将 ClawEmail 支持做成独立模块。
- 当前 Rust sidecar 已实现 Claw 子邮箱同步、缓存读取和 Coremail proxy 收件链路。
- Flutter 桌面端提供 Outlook / Claw 模式切换，并在 Claw 模式下显示独立的子邮箱与邮件读取入口。

## 当前项目定位

本项目当前定位为一个 Windows 桌面邮箱工作台，目标不是做网页管理后台，而是本地运行的绿色桌面工具。

核心设计原则：

- 本地优先：账号、邮件缓存和设置优先保存在本机。
- 桌面优先：界面、窗口、交互以 Windows 桌面软件为准。
- 模块化：Outlook 与 ClawEmail 作为不同通道实现，避免账号系统混用。
- 可维护：前端、API、数据库、收件适配保持清晰边界。

## 许可与合规说明

本文件记录的是参考来源和设计借鉴方向，不表示本项目复制或包含上述项目的源代码。

如果后续引入任何第三方项目的源码、资源、图标、协议实现或 SDK，应在本文件和对应源码目录中补充：

- 来源链接
- 使用范围
- 许可证
- 修改说明
- 是否随发行包分发
