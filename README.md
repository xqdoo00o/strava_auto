# Strava Auto

Strava Auto 是一个基于 Flutter 开发的跨平台运动数据同步工具，用来把分散在不同平台或文件中的运动记录更轻松地同步到 Strava。

它支持手动上传运动文件，也支持从顽鹿，iGPSPORT，Keep 等平台拉取活动后同步到 Strava。凭证仅保存在本地设备，活动数据只会在你主动触发同步时上传。

## 主要功能

- **运动文件上传**：支持选择或分享 `.fit`，`.tcx`，`.gpx` 文件并上传到 Strava。
- **运动类型设置**：上传时可选择默认类型跑步或骑行。
- **Strava API 同步**：通过 Strava API 连接账号并同步，适合已订阅 Strava 的账号。
- **Strava WebView 同步**：通过内置 WebView 登录 Strava 并同步，适合未订阅 Strava 的账号。
- **坐标纠偏**：可将 GCJ-02 坐标转换为 Strava 常用的 WGS84 坐标。
- **运动平台同步**：登录对应运动平台账号后，可按日期筛选活动并同步到 Strava。
- **顽鹿/iGPSPORT**：支持同步骑行活动。
- **佳明中国**：支持同步跑步/骑行活动。
- **Keep**：支持同步跑步/骑行活动，适合“小米/华为/OPPO 运动健康 -> Keep -> Strava”的数据流转。
- **多平台支持**：适配 Android、iOS、Web、Windows、macOS、Linux。
- **多语言与主题**：支持简体中文、英文，以及系统深色模式。

## 已订阅 Strava 账号准备工作

使用 Strava API 同步前，需要先创建一个 Strava API 应用：

1. 打开 [Strava API](https://www.strava.com/settings/api)。
2. 创建 API 应用。
3. 复制 **客户 ID** 和 **客户端密钥**。
4. 在 Strava Auto 的设置中填入对应信息。

如果使用 Web 版本，还需要把 Strava API 中的 **授权回调域** 配置为你的部署域名。

## 快速体验

在线演示地址：[https://strava.a2o.cc/](https://strava.a2o.cc/)

使用演示站前，请先将 [Strava API](https://www.strava.com/settings/api) 的 **授权回调域** 设置为：`strava.a2o.cc`

演示站基于 Web 版本部署。长期使用建议自行部署，以便使用自己的回调域名和 API 配置。

## 安装与部署

### Android

下载 [`app-release.apk`](../../releases/latest/download/app-release.apk) 并安装。

如果无法打开 Strava 授权页，可尝试更换系统默认浏览器。

### iOS

1. 前往 [AltStore 官网](https://altstore.io/) 下载并安装 AltServer。
2. 下载 [`Payload.ipa`](../../releases/latest/download/Payload.ipa)。
3. 在 AltStore 手机端选择该 IPA 文件进行侧载安装。
4. 受个人证书限制，需要每 7 天刷新一次证书。

### Web

1. 下载 [`web.zip`](../../releases/latest/download/web.zip)。
2. 打开 [Cloudflare Pages](https://pages.cloudflare.com/)。
3. 选择拖放文件，将 `web.zip` 上传并创建Pages部署。
4. 前往 [Strava API 设置页](https://www.strava.com/settings/api)，将 **授权回调域** 设置为 `pages.dev` 域名或你绑定的自定义域名。

### Web 本地扩展程序

适用于 Chrome 以及其他基于 Chromium 内核的桌面端浏览器。

1. 下载 [`web_extension.zip`](../../releases/latest/download/web_extension.zip) 并解压。
2. 打开浏览器的 [扩展程序管理页](chrome://extensions/)。
3. 点击 **加载未打包的扩展程序**，选择解压后的文件夹并加载。
4. 点击浏览器工具栏中的扩展图标即可使用。

### Windows

下载 [`Release.zip`](../../releases/latest/download/Release.zip)，解压后双击 `.exe` 文件运行。

### macOS

1. 下载 [`Strava.Auto.app.zip`](../../releases/latest/download/Strava.Auto.app.zip) 并解压。
2. 打开终端输入以下命令，将 `Strava Auto` 拖入终端补全路径并执行命令，执行后双击 `Strava Auto` 运行。

    ```
    xattr -dr com.apple.quarantine 
    ```

## 数据与隐私

- 本应用不会向作者服务器上传、收集或存储用户数据。
- Strava、顽鹿、iGPSPORT、Keep 等账号凭证仅保存在设备本地。
- 活动数据只会在你主动点击上传或同步时发送到 Strava。
- 请妥善保管自己的 API 配置和账号信息。

## 免责声明

本项目为个人开源项目，与 Strava、OneLap、iGPSPORT、Keep、Garmin 官方均无任何关联。

使用本应用产生的一切后果由用户自行承担，作者不承担任何直接或间接责任。

## 开源协议

本项目基于 **GNU General Public License v3.0 (GPL-3.0)** 协议开源。

如果你基于本项目进行修改、分发或开发衍生项目，也需要遵守 GPL-3.0 协议并开放相应源码。
