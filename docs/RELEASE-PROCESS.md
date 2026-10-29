# Cleariskind 发布流程（Release Process）

> 本文由源码仓维护，副本存放于发布仓供溯源。
> **发布是显式动作**：本地构建签名 → 人工确认 → 上传发布。**不依赖 push tag 自动发布。**
>
> 依据：源码仓 `docs/PRINCIPLES.md` 铁律 **R1**（发布纪律）—— R1-4 须可 10 分钟内撤回、R1-7 显式发布。

---

## 0. 一句话流程

```
源码仓（本地）
  ├─ ① 校验版本号三处一致
  ├─ ② cargo build --release -p featherfind-mcp -p featherfind-desktop
  ├─ ③ npx @tauri-apps/cli build --bundles nsis       → setup.exe + .sig
  ├─ ④ 打绿色 zip + 生成 latest.json（version 与 .sig 一致）
  └─ ⑤ tools/publish_release.py                        → 建 Release + 上传资产
                    │
                    ▼
发布仓:  Release vX.Y.Z
         - Cleariskind_X.Y.Z_x64-setup.exe
         - Cleariskind_X.Y.Z_x64-setup.exe.sig
         - Cleariskind_X.Y.Z_portable.zip
         - latest.json
         - featherfind-mcp.exe
                    │
                    ▼
客户端:  读 /releases/latest/download/latest.json → 提示更新
```

> **为什么不走 CI**：曾维护过一条 tag 触发的 GitHub Actions 流水线，实测**从未成功过一次**
> （`actions/secrets` 里三个必需 secret 一个都没有；唯一一次运行结论为 `failure`）。
> 且「push tag 自动发布」与铁律 R1-7 相悖。详见源码仓 `DECISIONS.md` **DEC-61**。

---

## 1. 仓库职责划分

| 仓库 | 可见性 | 内容 | 谁写 |
|---|---|---|---|
| **源码仓** `featherfind` | **私有** | 全部源码 + 内部文档（含业务信息，**不脱敏**） | 开发者 |
| **发布仓** `featherfind-releases` | **公开** | 仅 Release assets + 本文档 + README | **人工显式上传** |

> **为何分离**：源码仓含内网 IP 与公司业务文档；自动更新要求更新源匿名可访问 →
> 拆仓后**无需脱敏**，内部文档保持完整（见源码仓 `docs/GIT-RELEASE-PLAN.md §1`）。

---

## 2. 版本号单一真源（★ 关键）

**以 git tag 为准**（`vX.Y.Z`）。发布前须确认三处一致，不一致**不许发**：

| 位置 | 说明 |
|---|---|
| `Cargo.toml`（workspace `version`） | 编译期版本 |
| `desktop/tauri.conf.json`（`version`） | **Tauri 更新比对用的版本** —— 最关键 |
| git tag | 发布标识 |

> ⚠️ 版本号错乱会导致"反复提示更新"或"更新了仍显示旧版"。

### 2.1 ★ 第四处：`latest.json` 的 `version` —— 必须与签名一致（实测确认）

**2026-10-14 实测发现**：Tauri 的签名里**内嵌了版本号**，客户端会校验二者相等，
不一致则**直接拒绝更新**（`tauri-plugin-updater` 的 `verify_signed_version`）。

签名文件（`.sig`）解码后的第三行是 trusted comment，形如：

```
trusted comment: timestamp:1793286462	file:Cleariskind_1.0.0_x64-setup.exe	version:1.0.0
```

**规则**：

| 项 | 要求 |
|---|---|
| `latest.json` 的 `version` | **必须**等于 `.sig` 里的 `version:` 字段 |
| 不要手写 `version` | 从 `.sig` 的 trusted comment 里读出来填，或由脚本生成 |
| 不要改 `version` 指向旧包 | 这是**防篡改设计**，改了会被拒（这正是它的用途） |

**为什么容易踩**：`latest.json` 是纯文本，看着可以随手改版本号；
但签名覆盖的是"这个版本号的包"，所以**改版本号而不重签名 = 更新必失败**。

**校验命令**（发布前跑一次，零依赖）：

```bash
# 从签名里读出真实版本
base64 -d Cleariskind_X.Y.Z_x64-setup.exe.sig | sed -n '3p' | tr '\t' '\n' | grep '^version:'
# 与 latest.json 比对
grep '"version"' latest.json
```

### 2.2 验签的完整机制（供排查用）

客户端 `verify_signature()` 实际做了 **4 件事**，任一不过就中止：

| # | 检查 | 说明 |
|---|---|---|
| 1 | **key id 配对** | 签名内的 key id 必须等于程序内置公钥的 key id |
| 2 | **数据签名** | 签名算法 `ED`(0x4544) = 预哈希模式 → 先对安装包做 **BLAKE2b-64**，再 Ed25519 验签 |
| 3 | **全局签名** | 覆盖 `(签名本身 + trusted comment 去掉 17 字符前缀)` —— 防止注释被改 |
| 4 | **版本一致** | trusted comment 的 `version:` == 清单 `version` |

> ⚠️ 注意第 2 条：是 **BLAKE2b**，不是 SHA-256/SHA-512。自己写校验脚本时最容易搞错。

---

## 3. 发布步骤（全部人工，逐条可核）

```bash
# 1. 同步版本号（Cargo.toml + desktop/tauri.conf.json，两处须相同），然后提交
git commit -am "chore(release): vX.Y.Z"

# 2. 构建两个产物（GNU 工具链）
export CARGO_TARGET_DIR="D:\cargo-target\featherfind"
cargo build --release -p featherfind-mcp -p featherfind-desktop

# 3. 打 NSIS 安装包并签名
#    ★ 不要用 cargo install tauri-cli（本机 crates.io 反复 0 字节超时，实测 10 分钟全废）
cd desktop
TAURI_SIGNING_PRIVATE_KEY=$HOME/.tauri/featherfind.key \
TAURI_SIGNING_PRIVATE_KEY_PASSWORD="" \
npx --yes @tauri-apps/cli@2.12.3 build --bundles nsis
cd ..

# 4. 装配交付物：绿色 zip + latest.json（version 必须取自 .sig）

# 5. 显式发布（幂等：同名 Release 复用，同名资产先删后传）
python tools/publish_release.py --tag vX.Y.Z --version X.Y.Z \
    --notes-file docs/release-notes-vX.Y.Z.md \
    --assets out/Cleariskind_X.Y.Z_x64-setup.exe \
             out/Cleariskind_X.Y.Z_x64-setup.exe.sig \
             out/Cleariskind_X.Y.Z_portable.zip \
             out/latest.json out/featherfind-mcp.exe

# 6. 推送源码仓（tag 只作标识，不触发发布）
git tag -a vX.Y.Z -m "Cleariskind X.Y.Z" && git push origin main --tags
```

### 3.1 发布后必做的核验（不能只信脚本输出）

用**公开 API / 匿名下载**逐项确认，而不是看脚本打印了什么：

| 项 | 命令 | 通过标准 |
|---|---|---|
| `latest` 解析 | `curl -s .../releases/latest` | tag 为本版，`prerelease=false` |
| 清单可达 | `curl -sL .../releases/latest/download/latest.json` | HTTP 200，`version` 为本版 |
| 资产可下载 | 匿名 `curl -L` 下载 setup.exe | HTTP 200，**md5 与本地一致** |
| 签名同源 | 解 `.sig` 看 key id | 与 `tauri.conf.json` 公钥一致 |

---

## 4. 本机工具链的坑（实测，来自源码仓）

| # | 坑 | 表现 | 处置 |
|---|---|---|---|
| 1 | **缺 `as.exe`** | dlltool **静默**产出 0 字节导入库 | 用完整 MinGW（含 `as`） |
| 3 | **`windres` 缺 `cc1`** | 资源编译失败 | 用完整 MinGW，勿用 Rust self-contained 的 linker-only gcc |
| 4 | **缺 `WebView2Loader.dll`** | 用户装完**打不开** | **必须打进安装包/zip** |
| 7 | **缺 `ld.exe`** | 构建在 LTO 阶段**静默卡 13 分钟** | PATH 加入 rustup `self-contained` |
| 8 | **NSIS 未安装** | bundling 失败 | Tauri bundler 会自动下载到 `%LOCALAPPDATA%\tauri\NSIS` |
| 9 | **`cargo install tauri-cli` 不可行** | crates.io 反复 `transferred 0 bytes` | 改用 `npx @tauri-apps/cli` |
| 10 | **打包会 patch exe** | Tauri 给 `release/*.exe` 写入 bundle type，体积略变 | **绿色版必须用未 patch 的那份**，NSIS 用 patch 后的 |

---

## 5. 签名密钥管理

| 项 | 做法 |
|---|---|
| 私钥 | 存放于开发机 `~/.tauri/featherfind.key`（**无口令**生成），**永不入仓库、不入 CI** |
| 公钥 | 内置客户端（`desktop/tauri.conf.json` 的 `plugins.updater.pubkey`），与 `.key.pub` 逐字节一致 |
| 轮换 | 若私钥泄漏，需**发紧急版本**并在客户端内置**双公钥**过渡（否则老客户端无法验证） |

> ⚠️ **签名不可关闭**（Tauri 官方原文：*"This cannot be disabled."*）。

---

## 6. 发布前检查清单

**A 组 · 硬门禁（必过，见铁律 R1-1）**

- [ ] **导入完整性**：`python tools/check_imports.py dist\featherfind-desktop.exe` 零缺失
- [ ] **真实启动**：双击启动，进程存活 + WebView2 子进程出现 + 界面可操作
- [ ] **体积**：桌面 ≤ 6 MB · MCP ≤ 2.5 MB（DEC-37/38）

**B 组 · 质量项**

- [ ] `cargo fmt --all --check` 无 diff
- [ ] `cargo clippy -- -D warnings`（受环境限制的须如实记录）
- [ ] 三处版本号一致
- [ ] `WebView2Loader.dll` 已打包
- [ ] 两个 exe 均为**本次新构建**（防发布旧产物 —— 曾发现 `dist/` 里有旧 exe）
- [ ] 安装包为 **per-user**（`installMode: currentUser`，免管理员）
- [ ] `.sig` 已生成并上传
- [ ] `latest.json` 的 `url` 指向本次 Release 的**实际资产名**
- [ ] `latest.json` 的 `version` == `.sig` 里的 `version`

**C 组 · 升级演练（首次发布豁免，见 R1-6）**

- [ ] 在**已装上一版**的机器上走通「检测→下载→验签→安装→重开」，
      且**用本地 endpoint**，不改写线上 release 资产

**最后**

- [ ] Release notes 已写，且**如实列出已知限制**（R1-3）
- [ ] 确认可撤回：删该 Release + `latest.json` 改指上一版，**10 分钟内能完成**（R1-4）
