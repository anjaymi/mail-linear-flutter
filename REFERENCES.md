# 项目参考说明

本项目不是某个开源项目的直接 fork，也没有直接复制下列项目源码。本项目在开发过程中参考了若干开源项目的产品思路、功能边界和接口方向，并重新实现为当前的 Flutter 桌面端 + Rust 本地 sidecar 架构。

## 参考项目

- [Maishan-Inc / Microsoft-Email-Manager](https://github.com/Maishan-Inc/Microsoft-Email-Manager)
  - 参考 Microsoft / Outlook 邮箱账号管理、批量邮箱管理和账号状态处理思路。

- [aa1125573296-svg / Outlook-Mail-Manager](https://github.com/aa1125573296-svg/Outlook-Mail-Manager)
  - 参考 Outlook 令牌账号导入格式、批量账号管理流程和邮箱工具基础功能组织。

- [fengyuanluo / firemail](https://github.com/fengyuanluo/firemail)
  - 参考邮件客户端的阅读体验、收件箱列表和邮件阅读区的布局思路。

- [WangXingFan / ClawEmail](https://github.com/WangXingFan/ClawEmail)
  - 参考 ClawEmail 绑定流程、子邮箱管理和 Coremail proxy 收件方向。

## 当前实现说明

本项目当前实现为独立的 Windows 桌面邮箱工作台：

- Flutter 负责桌面端界面。
- Rust sidecar 负责本地 API、收件、缓存和 ClawEmail 适配。
- Outlook 与 ClawEmail 作为不同通道实现，避免账号系统混用。
- 账号、邮件缓存和设置优先保存在本机。

## 合规说明

本文件仅记录参考来源和设计借鉴方向，不表示本项目包含上述项目源码。

如果后续引入任何第三方项目的源码、资源、图标、协议实现或 SDK，应补充来源链接、使用范围、许可证和修改说明。
