# Phone Agent iOS

自研 iOS 客户端：WebSocket 常连 + 静音保活 + CallKit 来电 + 语音播报。

没有 Mac 也能出包：靠 GitHub Actions 的免费 macOS 机器编译，再用 AltStore 用免费 Apple ID 签名安装。

## 目录

```
ios/
  project.yml          XcodeGen 工程描述（不提交 .xcodeproj）
  Sources/
    App.swift          入口
    Store.swift        状态 + WebSocket + 业务
    Models.swift       数据模型 + HTTP 客户端
    CallManager.swift  CallKit 来电 + 播报 + 自动挂断
    KeepAlive.swift    静音音频保活
    Notify.swift       本地通知（兜底）
    Views.swift        对话 / 任务 / 设置三个页面
.github/workflows/
  build-ios.yml        编译 + 打包 ipa
```

## 一、推上 GitHub

1. 注册 GitHub 账号（已有就跳过）
2. 新建一个仓库，建议 **Public**（Actions 免费不限时长；代码里没有密钥，公开无风险）
3. 把 `phone-agent` 这个目录里的 **`ios/` 和 `.github/` 两个文件夹** 拖进仓库页面的上传区

   > GitHub 网页版可以直接拖文件夹上传，不需要装 git。

4. 提交

## 二、编译

仓库页面 → **Actions** 标签 → 左侧 `Build iOS IPA` → 右侧 **Run workflow**。

第一次大约 5–8 分钟（要装 XcodeGen、编译 Swift）。

跑完后点进这次运行，页面底部 **Artifacts** 里下载 `PhoneAgent-ipa`，解压得到 **`PhoneAgent.ipa`**。

## 三、签名安装（Windows 上做）

### 装 AltServer

1. 去 https://altstore.io 下载 **AltServer (Windows)**
2. **必须**先装苹果官网版本的 iTunes 和 iCloud（不能是 Microsoft Store 版）
   - iTunes: https://www.apple.com/itunes/download/win64
   - iCloud: https://support.apple.com/zh-cn/106189
3. 装好 AltServer，任务栏出现图标，用你的 **Apple ID 登录**（免费账号即可）

### 装 AltStore 到手机

1. iPhone 用数据线连电脑，信任此电脑
2. 任务栏 AltServer 图标 → **Install AltStore** → 选你的 iPhone → 输入 Apple ID 和密码
3. 手机上会多出 **AltStore**（如果提示"不受信任的开发者"，去 设置 → 通用 → VPN与设备管理 → 信任）

### 装我们的 App

1. 把 `PhoneAgent.ipa` 传到手机（微信文件传输 / iCloud 云盘 / 邮件都行）
2. 打开 AltStore → **My Apps** → 左上角 **+** → 选那个 ipa
3. 等它签完，桌面出现「私人助理」

> 也可以在电脑上用 AltServer：图标 → **Sideload .ipa**

## 四、首次配置

1. 打开 App → 设置
2. 服务器填：`http://103.236.88.39:55110`
3. Token 填：你服务器 `.env` 里的 `API_TOKEN`
4. 点「保存并重连」，再点「测试连接」，应显示"连接成功 · 手机在线 1"
5. 切到「对话」发一条消息试试

## 五、怎么让它到点弹来电

1. 打开 App 后**不要划掉它**，让它留在后台
2. 设置里确认「保活（静音音频）」是开的
3. 服务器到点推送 `incoming_call` → 手机弹出全屏来电 → 接听 → 念任务 → 自动挂断

App 没运行时：本地通知会在同一时刻响（声音是普通通知音）。

## 六、已知限制

| 限制 | 说明 |
|---|---|
| 7 天过期 | 免费证书签的 App 每 7 天失效一次，用 AltStore 重新签（连电脑或同 WiFi 自动刷新） |
| 保活耗电 | 静音音频会持续占音频通道，一天多 10–20% 电量 |
| iOS 更新可能失效 | 保活依赖系统行为，大版本升级后建议重新验证 |
| 不能上架 | 自用侧载，不涉及 App Store 审核 |

## 七、排错

| 现象 | 处理 |
|---|---|
| Actions 报 `xcodegen: command not found` | brew 那步失败了，重跑一次 |
| 编译报 `No such module 'CallKit'` | 检查 `-sdk iphoneos` 是否传对 |
| AltStore 安装报 `The operation couldn't be completed` | 换 Apple ID，或先在设置里注销再登录 |
| App 里一直"已断开，重连中" | 检查服务器地址是否带 `http://`，以及 NAT 端口对不对 |
| 到点不弹来电 | 先看 App 是否还被系统挂起，重新打开一次 |
