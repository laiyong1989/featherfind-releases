# FeatherFind 发布流程（Release Process）

> 本文由源码仓维护，副本存放于发布仓供溯源。**所有步骤由 CI 自动执行**，人工只负责"打标签"。

---

## 0. 一句话流程

```
源码仓: 开发者打 tag (v0.2.0)
          │
          ▼
    GitHub Actions (windows-latest)
          │  ① 校验版本号三处一致
          │  ② 构建 (GNU 工具链)
          │  ③ 打包 NSIS 安装包 + 绿色 zip
          │  ④ minisign 签名（私钥取自 Secrets）
          ▼
   发布仓: 创建 Release + 上传 assets
          │  - FeatherFind_x.y.z_x64-setup.exe
          │  - FeatherFind_x.y.z_x64-setup.exe.sig
          │  - latest.json
          │  - featherfind-mcp.exe / WebView2Loader.dll
          ▼
   客户端: 检查 /releases/latest/download/latest.json → 提示更新
```

---

## 1. 仓库职责划分

| 仓库 | 可见性 | 内容 | 谁写 |
|---|---|---|---|
| **源码仓** `featherfind` | **私有** | 全部源码 + 内部文档（含业务信息，**不脱敏**） | 开发者 |
| **发布仓** `featherfind-releases` | **公开** | 仅 Release assets + 本文档 + 本 README | **CI 自动**（人工几乎不碰） |

> **为何分离**：源码仓含内网 IP 与公司业务文档；自动更新要求更新源匿名可访问 →
> 拆仓后**无需脱敏**，内部文档保持完整（见源码仓 `docs/GIT-RELEASE-PLAN.md §1`）。

---

## 2. 版本号单一真源（★ 关键）

**以 git tag 为准**（`vX.Y.Z`）。CI 会校验三处一致，不一致则**构建失败**：

| 位置 | 说明 |
|---|---|
| `Cargo.toml`（workspace `version`） | 编译期版本 |
| `desktop/tauri.conf.json`（`version`） | **Tauri 更新比对用的版本** —— 最关键 |
| git tag | 发布触发源 |

> ⚠️ **版本号错乱会导致"反复提示更新"或"更新了仍显示旧版"**。

---

## 3. 发布步骤（人工部分）

```bash
# 1. 在源码仓：改版本号（三处）
./scripts/bump-version.sh 0.2.0

# 2. 提交并打标签
git commit -am "chore(release): v0.2.0"
git tag v0.2.0

# 3. 推送（触发 CI）
git push origin main --tags
```

其余全自动。

---

## 4. CI 必须处理的坑（来自源码仓实战）

| # | 坑 | CI 上的表现 | 处置 |
|---|---|---|---|
| 1 | **缺 `as.exe`** | dlltool 静默产出 0 字节导入库 | CI 安装完整 MinGW（含 `as`） |
| 3 | **`windres` 缺 `cc1`** | 资源编译失败 | 用完整 MinGW，勿用 Rust self-contained 的 linker-only gcc |
| 4 | **缺 `WebView2Loader.dll`** | 用户装完**打不开** | **必须打进安装包/zip** |
| 7 | **缺 `ld.exe`** | 构建在 LTO 阶段**静默卡 13 分钟** | PATH 加入 rustup `self-contained` |
| 8 | **NSIS 未安装** | bundling 失败 | Tauri bundler 会自动下载；或预装到缓存 |
| 9 | **GNU + NSIS 兼容性** | 【需实测 T-13】官方称仅支持 MSVC | 见源码仓 `DEC-44` 降级预案 |

---

## 5. 签名密钥管理

| 项 | 做法 |
|---|---|
| 私钥 | 生成后存 **源码仓的 GitHub Secrets**（`TAURI_SIGNING_PRIVATE_KEY`），**永不入仓库** |
| 公钥 | 内置客户端（`tauri.conf.json` 的 `plugins.updater.pubkey` 或自研方案常量） |
| 轮换 | 若私钥泄漏，需**发紧急版本**并在客户端内置**双公钥**过渡（否则老客户端无法验证） |

> ⚠️ **签名不可关闭**（Tauri 官方原文：*"This cannot be disabled."*）。
> 自研方案同样**必须**有签名校验，否则可被投毒。

---

## 6. 发布前检查清单

- [ ] 三处版本号一致（CI 会自动校验）
- [ ] `WebView2Loader.dll` 已打包
- [ ] 两个 exe 均为**本次新构建**（防发布旧产物 —— 曾发现 `dist/` 里有旧 exe）
- [ ] 安装包为 **per-user**（`installMode: currentUser`，免管理员）
- [ ] `.sig` 文件已生成并上传
- [ ] `latest.json` 的 `url` 指向本次 Release 的**实际资产名**
- [ ] Release notes 已写（客户端会展示给用户）
- [ ] **体积复核**：桌面 ≤ 6 MB · MCP ≤ 2.5 MB（DEC-37/38）
