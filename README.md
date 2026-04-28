# Strava Auto

这是一个基于 Flutter 开发的 Strava 数据同步工具，旨在解决运动数据在不同平台间流转的难题。

## ✨ 主要功能

*   **运动文件上传**：支持手动选择或通过系统分享直接上传 .fit .tcx .gpx 文件到 Strava，支持修改运动类型（骑行/跑步）。
*   **Strava API**：内置 Strava 授权，无需手动填写 Token。
*   **坐标纠偏**：国标GCJ-02坐标系的文件可转换为Strava支持的通用标准WGS84坐标系。
*   **顽鹿自动同步**：登录顽鹿账号后，可手动同步骑行活动到Strava，支持筛选日期同步。
*   **iGPSPORT自动同步**：登录iGPSPORT账号后，可手动同步骑行活动到Strava，支持筛选日期同步。
*   **Keep自动同步**：登录Keep账号后，可手动同步跑步活动到Strava，支持筛选日期同步（小米/华为/OPPO运动健康数据->Keep->Strava）。
*   **多平台/语言支持**：适配 iOS/Android, Windows/macOS，支持简体中文和英文。
*   **原生体验**：适配 iOS/Android 深色模式与系统交互。
*   **数据安全**：凭证仅保存在设备本地。

## 注册 Strava API

1. 登录 https://www.strava.com/settings/api, 并创建应用。
2. 复制 Client ID 和 Client Secret 填入 App 设置。

## 使用方式

### 安卓

下载apk文件并安装，如无法打开Strava授权页，请尝试更改默认浏览器。

### iOS

下载安装[AltStore](https://altstore.io/), 下载ipa文件并侧载，注意每七天需刷新证书。

### Windows

下载zip文件并解压，双击exe文件运行。

## 免责声明 / Disclaimer

本应用为个人开源项目，与 OneLap/iGPSPORT/Keep 及 Strava 官方无任何关联。使用本应用所产生的一切后果由用户自行承担，作者不承担任何责任。本应用不向任何第三方或作者服务器收集、传输用户数据。活动数据仅在你主动触发同步时上传至 Strava。所有凭证仅保存在设备本地。

## 📄 开源协议

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 协议开源。
这意味着如果您基于本项目修改或开发衍生项目，也必须开源。
