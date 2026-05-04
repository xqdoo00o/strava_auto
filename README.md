# Strava Auto

这是一个基于 Flutter 开发的 Strava 数据同步工具，旨在解决运动数据在不同平台间流转的难题。

## ✨ 主要功能

*   **运动文件上传**：支持手动选择或通过系统分享直接上传 .fit .tcx .gpx 文件到 Strava，支持修改运动类型（骑行/跑步）。
*   **Strava API**：内置 Strava 授权，无需手动填写 Token。
*   **坐标纠偏**：国标GCJ-02坐标系的文件可转换为Strava支持的通用标准WGS84坐标系。
*   **顽鹿同步**：登录顽鹿账号后，可手动同步骑行活动到Strava，支持筛选日期同步。
*   **iGPSPORT同步**：登录iGPSPORT账号后，可手动同步骑行活动到Strava，支持筛选日期同步。
*   **Keep同步**：登录Keep账号后，可手动同步跑步活动到Strava，支持筛选日期同步（小米/华为/OPPO运动健康数据->Keep->Strava）。
*   **多平台/语言支持**：适配 iOS/Android, Windows/Web/macOS/Linux，支持简体中文和英文。
*   **原生体验**：适配 iOS/Android 深色模式与系统交互。
*   **数据安全**：凭证仅保存在设备本地。

## 注册 Strava API

1. 前往 https://www.strava.com/settings/api, 并创建应用。
2. 复制 客户 ID 和 客户端密钥 填入 App 设置。

## 快速体验

[在线演示地址](https://strava.a2o.cc/)

- **说明**：使用前请将 [Strava API](https://www.strava.com/settings/api) 中 **授权回调域** 修改为 `strava.a2o.cc`，否则将无法连接 Strava。
- **提示**：参考下方[使用方式](#使用方式)，建议自行部署使用，演示地址使用 [Web](#web) 方式部署。

## 使用方式

### 安卓

下载 [`app-release.apk`](../../releases/latest/download/app-release.apk) 文件并安装，如无法打开Strava授权页，请尝试更改默认浏览器。

### iOS

1. **安装环境**：前往 [AltStore 官网](https://altstore.io/) 下载并安装 AltServer。
2. **侧载应用**：下载 [`Payload.ipa`](../../releases/latest/download/Payload.ipa) 文件，通过 AltStore 手机端选择该文件进行安装。
3. **定期续签**：受限于个人证书，请**每 7 天**刷新一次证书。

### Web

1. **托管部署**：下载 [`web.zip`](../../releases/latest/download/web.zip) 文件，部署至 [Cloudflare Pages](https://pages.cloudflare.com/)，选择 **拖放文件**，将该文件拖入并部署Pages。
2. **配置回调**：前往 [Strava API](https://www.strava.com/settings/api)，将 **授权回调域** 修改为 `pages.dev` 或Pages绑定的自定义域。

### Windows

下载 [`Release.zip`](../../releases/latest/download/Release.zip) 文件并解压，双击exe文件运行。

## 免责声明

本应用为个人开源项目，与 OneLap/iGPSPORT/Keep 及 Strava 官方无任何关联。使用本应用所产生的一切后果由用户自行承担，作者不承担任何责任。本应用不向任何第三方或作者服务器收集、传输用户数据。活动数据仅在你主动触发同步时上传至 Strava。所有凭证仅保存在设备本地。

## 📄 开源协议

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 协议开源。
这意味着如果您基于本项目修改或开发衍生项目，也必须开源。
