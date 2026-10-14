#!/usr/bin/env bash
# ============================================================
#  FeatherFind · 敏感信息泄漏扫描
#
#  用途：在**公开仓库**（发布仓）推送前 / CI 中运行，
#        确保内部信息没有误入公开面。
#
#  用法：
#     ./scripts/check-leaks.sh [目录]        # 默认当前目录
#
#  退出码：0 = 干净；1 = 发现疑似泄漏
#
#  背景：源码仓（私有）含内网 IP 与公司业务文档；
#        发布仓（公开）必须**零内部信息**。
#        见 docs/GIT-RELEASE-PLAN.md §1。
#
#  ★ 设计要点：本脚本会随公开仓一起发布，因此
#    **不得在脚本内硬编码任何内部标识**（公司名、共享目录名等），
#    否则"扫描器自身"就成了泄漏源（此坑已实测踩过，见 §自定义规则）。
# ============================================================
set -uo pipefail

TARGET="${1:-.}"
cd "$TARGET"

FAIL=0

# —— 扫描规则（正则 + 说明）——
# 注意：这里只放"通用且不敏感"的模式。
scan() {
  local label="$1" pat="$2" hint="$3"
  local hits
  hits=$(grep -rInE "$pat" . \
           --exclude-dir=.git --exclude-dir=node_modules \
           --exclude-dir=target --exclude-dir=toolchain \
           2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "❌ [$label] 发现 $(printf '%s\n' "$hits" | wc -l) 处匹配"
    printf '%s\n' "$hits" | head -5 | sed 's/^/     /'
    echo "     → $hint"
    FAIL=1
  else
    echo "✅ [$label] 干净"
  fi
}

# —— 自定义规则（内部标识）：从外部注入，**不入库** ——
# 公司实体名、内部共享目录名等属私有信息，不能写进本文件。
# 三种注入方式（任一即可）：
#   ① 环境变量：export FF_LEAK_PATTERNS='实体A|实体B|目录甲'
#   ② 文件：    ~/.config/featherfind/leak-patterns.txt（每行一个正则）
#   ③ CI Secret：把该值注入 FF_LEAK_PATTERNS
ff_custom_patterns() {
  if [ -n "${FF_LEAK_PATTERNS:-}" ]; then
    printf '%s' "$FF_LEAK_PATTERNS"
    return
  fi
  local f="${FF_LEAK_PATTERNS_FILE:-$HOME/.config/featherfind/leak-patterns.txt}"
  if [ -f "$f" ]; then
    grep -vE '^\s*(#|$)' "$f" | paste -sd'|' -
  fi
}

echo "=============================================="
echo " FeatherFind 泄漏扫描: $(pwd)"
echo "=============================================="
echo

echo "--- 1. 内网地址 / 私有 IP ---"
scan "内网 IP" \
     '\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})\b' \
     "内网地址不应出现在公开仓库"
scan "UNC 共享路径" \
     '\\\\\\\\[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' \
     "UNC 路径会暴露内网主机"

echo
echo "--- 2. 内部业务标识（模式来自外部注入，脚本内不含具体名称）---"
CUSTOM="$(ff_custom_patterns)"
if [ -n "$CUSTOM" ]; then
  scan "自定义内部标识" "$CUSTOM" "内部业务标识不应出现在公开仓库"
else
  echo "⚠️  [自定义内部标识] 未提供模式 —— 已跳过"
  echo "     如需扫描公司名/共享目录名等，请设置 FF_LEAK_PATTERNS"
  echo "     （本脚本刻意不含具体名称：它自身会随公开仓发布）"
fi

echo
echo "--- 3. 凭据 / 密钥 ---"
scan "私钥文件" \
     'BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY' \
     "私钥绝不可入仓库"
scan "GitHub Token" \
     'gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,}' \
     "Token 绝不可入仓库"
scan "泛化密钥赋值" \
     '(api[_-]?key|secret|password|token)\s*[:=]\s*["'\''][A-Za-z0-9/+=_-]{16,}["'\'']' \
     "疑似硬编码密钥"

echo
echo "--- 4. 本机路径 / 用户名 ---"
scan "本机绝对路径" \
     '[Cc]:[/\\]Users[/\\][A-Za-z0-9_.-]+' \
     "本机用户名会泄漏开发者身份"

echo
echo "=============================================="
if [ "$FAIL" -eq 0 ]; then
  echo " ✅ 扫描通过：未发现疑似泄漏"
else
  echo " ❌ 扫描未通过：请处置上述问题后再推送"
  echo "    （如确属误报，请调整本脚本的规则）"
fi
echo "=============================================="
exit "$FAIL"
