# FeatherFind · Releases

> **本仓库只存放 FeatherFind 的发布产物（二进制 + 更新清单），不含源码。**
> 用途：作为客户端**自动更新**的公开更新源。

---

## 这是什么

[FeatherFind](https://github.com/) 是一款 Windows 轻量本地文件检索工具（Rust + Tauri，MCP 接口）。

本仓库是它的**发布分发通道**，源码与开发文档在另一个（私有）仓库中维护。
**分离的原因**：源码仓含内部业务文档，而自动更新要求更新源可被终端用户匿名访问，故拆为两仓。

---

## 用户如何安装

1. 打开本仓库的 [Releases](../../releases) 页面
2. 下载最新版本的 `FeatherFind_x.y.z_x64-setup.exe`
3. 双击安装（**per-user 安装，无需管理员权限**）
4. 启动后即可使用；索引范围可在侧栏中调整

---

## 自动更新

程序内置更新检查（**默认关闭**，可在侧栏「更新」中开启）。开启后：

- 每 24 小时（或你手动点击时）访问本仓库的 `latest.json` 检查新版本
- 发现新版本 → **状态栏提示 + 侧栏角标**（不打断当前操作，不弹窗）
- 你确认后下载 → **minisign 签名校验** → 校验通过才启动安装
- 点击「退出并安装」后：程序退出 → 安装程序接管 → **自动打开新版本**

> 更新过程中的下载进度、校验状态、失败原因都会在侧栏「更新」中如实显示。
> 界面**不使用假进度**：无法获知文件大小时改用不确定进度条；下载完成前不会显示 100%。

### 隐私说明

更新检查会**访问 GitHub（出网）**，但：

- ✅ 只发送 HTTP 请求（含你的 IP 与 User-Agent，这是任何网络请求的固有信息）
- ❌ **不上传**你的索引、文件列表、搜索历史或任何使用数据

> 本程序「零上报」——即**不上传任何本地数据**；但「零上报」不等于「零联网」，
> 更新检查是用户**显式开启**的可选功能。关闭开关后，程序**不会**发起任何网络请求。

---

## 更新清单（latest.json）

随 Release 上传（与安装包**同一版本**），格式如下：

```json
{
  "version": "0.1.1",
  "notes": "本次更新内容摘要（Markdown）",
  "pub_date": "2026-10-14T12:31:02Z",
  "platforms": {
    "windows-x86_64": {
      "signature": "<minisign 签名>",
      "url": "https://github.com/laiyong1989/featherfind-releases/releases/download/v0.1.1/FeatherFind_0.1.1_x64-setup.exe"
    }
  }
}
```

客户端读取路径（**不消耗 GitHub API 限额**）：

```
https://github.com/laiyong1989/featherfind-releases/releases/latest/download/latest.json
```

> ⚠️ `version` 字段**必须**与安装包签名（`.sig`）内记录的版本一致，
> 否则客户端会拒绝更新（这是防篡改设计）。详见 [`docs/RELEASE-PROCESS.md`](docs/RELEASE-PROCESS.md) §2.1。

---

## 发布流程

见 [`docs/RELEASE-PROCESS.md`](docs/RELEASE-PROCESS.md)（由源码仓的 CI 自动执行，本仓库由 CI 写入）。

---

## 许可

见 Release 中的 `LICENSE`。本项目采用 **MIT OR Apache-2.0**（DEC-33）。

---

## 安全

- 所有发布产物均带 **minisign 签名**；客户端**强制校验**，校签失败即中止更新
- 公钥内置于客户端二进制；私钥仅存于源码仓的 GitHub Secrets
- **拒绝降级**：客户端不会安装比当前更旧的版本
