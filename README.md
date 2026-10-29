# Cleariskind · Releases

> **本仓库只存放 Cleariskind 的发布产物（二进制 + 更新清单），不含源码。**
> 用途：作为客户端**自动更新**的公开更新源。

---

## 这是什么

Cleariskind 是一款 Windows 本地文件检索工具（Rust + Tauri）：像 Everything 一样秒搜文件名，
但**关掉再打开依然秒出结果**——索引会落盘，不必每次重建。

本仓库是它的**发布分发通道**。源码与开发文档在另一个（私有）仓库维护。

**为什么拆两个仓**：自动更新要求更新源能被终端用户**匿名访问**，而源码仓含内部资料。
拆开后两边各取所需，不需要为了公开而删改内部文档。

---

## 安装

1. 打开 [Releases](../../releases) 页面，选最新的 `v1.x`
2. 下载 **`Cleariskind_x.y.z_x64-setup.exe`**
3. 双击安装 —— **per-user 安装，无需管理员权限**
4. 启动即用；检索范围可在侧栏「搜索位置」里调整

### 每个资产是什么

| 文件 | 说明 |
|---|---|
| `Cleariskind_x.y.z_x64-setup.exe` | **安装包**（推荐） |
| `Cleariskind_x.y.z_x64-setup.exe.sig` | 安装包的 minisign 签名，客户端用它校验 |
| `Cleariskind_x.y.z_portable.zip` | **绿色版**，解压即用，不写注册表 |
| `latest.json` | 自动更新清单（客户端读取） |
| `featherfind-mcp.exe` | MCP 服务端，供 AI 客户端单独调用 |

> 绿色版**必须把 `WebView2Loader.dll` 与 exe 放在同一目录**，否则启动报
> 「找不到 WebView2Loader.dll」。zip 里已包含该 DLL。

### 系统要求

- Windows 10 / 11（x64）
- **WebView2 Runtime** —— Windows 11 自带；Windows 10 一般随 Edge 已安装。
  若提示缺失，装一次 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) 即可。

---

## 自动更新

程序内置更新检查，**默认关闭**，可在设置里开启。开启后：

- 每 24 小时（或手动点击时）读取本仓库的 `latest.json` 检查新版本
- 发现新版本 → **状态栏提示 + 侧栏角标**（不弹窗，不打断当前操作）
- 你确认后下载 → **minisign 签名校验** → 通过才启动安装
- 点「退出并安装」→ 程序退出 → 安装程序接管 → 自动打开新版本

> 下载进度、校验状态、失败原因都会在侧栏如实显示。
> 界面**不使用假进度**：拿不到文件大小时用不确定进度条；下载完成前不会显示 100%。

### 隐私说明

更新检查会**访问 GitHub（出网）**，但：

- ✅ 只发 HTTP 请求（含你的 IP 与 User-Agent，这是任何网络请求的固有信息）
- ❌ **不上传**索引、文件列表、搜索历史或任何使用数据

> 本程序「零上报」= **不上传任何本地数据**；但「零上报」≠「零联网」。
> 更新检查是用户**显式开启**的可选功能，关掉后程序**不发起任何网络请求**。

---

## 更新清单（latest.json）

随 Release 上传，与安装包**同版本**。当前 `v1.0.0` 的实际内容：

```json
{
  "version": "1.0.0",
  "notes": "发布说明（Markdown，客户端会展示给用户）",
  "pub_date": "2026-10-29T15:08:09Z",
  "platforms": {
    "windows-x86_64": {
      "signature": "<minisign 签名，取自 .sig 文件内容>",
      "url": "https://github.com/laiyong1989/featherfind-releases/releases/download/v1.0.0/Cleariskind_1.0.0_x64-setup.exe"
    }
  }
}
```

客户端读取路径（**不消耗 GitHub API 限额**）：

```
https://github.com/laiyong1989/featherfind-releases/releases/latest/download/latest.json
```

> ⚠️ `latest.json` 的 `version` **必须**与安装包 `.sig` 内记录的 `version:` 一致，
> 否则客户端**拒绝更新**（防篡改设计，见 [`docs/RELEASE-PROCESS.md`](docs/RELEASE-PROCESS.md) §2.1）。
> 换句话说：**改版本号而不重签名 = 更新必失败。**

---

## 发布流程

见 [`docs/RELEASE-PROCESS.md`](docs/RELEASE-PROCESS.md)。

简述：在源码仓**本地构建 + 签名**，然后**显式上传**到本仓库（不依赖 push tag 自动发布）。

---

## 安全

- 所有发布产物均带 **minisign 签名**，客户端**强制校验**，失败即中止更新
- 公钥内置于客户端二进制；私钥不存于任何仓库，也不在 CI 里
- **拒绝降级**：客户端不会安装比当前更旧的版本
- 验签覆盖「安装包内容 + 签名注释 + 版本号」三部分，任一被改都会失败

---

## 许可

**MIT OR Apache-2.0**，可任选其一。
