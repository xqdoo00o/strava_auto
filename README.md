# Strava Auto

这是一个基于 Flutter 开发的 Strava 数据同步工具，旨在解决运动数据在不同平台间流转的难题。

## ✨ 主要功能

*   **运动文件上传**：支持手动选择或通过系统分享直接上传 .fit .gpx .tcx 文件到 Strava，支持修改运动类型。
*   **Strava API**：内置 Strava 授权，无需手动填写 Token。
*   **坐标纠偏**：国标GCJ-02坐标系的文件可转换为Strava支持的通用标准WGS84坐标系。
*   **顽鹿自动同步**：登录顽鹿账号后，自动后台检测并同步骑行记录到 Strava。
*   **多语言支持**：支持简体中文和英文。
*   **原生体验**：适配 iOS/Android 深色模式与系统交互。
*   **数据安全**：凭证仅保存在设备本地。


## 注册 Strava API

1. 登录 https://www.strava.com/settings/api, 并创建应用。
2. 复制 Client ID 和 Client Secret 填入 App 设置。

## 📄 开源协议

本项目采用 **GNU General Public License v3.0 (GPL-3.0)** 协议开源。
这意味着如果您基于本项目修改或开发衍生项目，也必须开源。
