#!/usr/bin/env bash
# ~/.claude/statusline.sh — Claude Code session status line (aesthetic edition)
#
# 單行輸出：
#   ◆ 模型 │ 漸層進度條 百分比 │ effort 推理強度 │ In:輸入 Out:輸出 token │ 時間 │ 速率限制 │ ⎇分支* │ 目錄
#
# 環境變數：
#   CLAUDE_STATUSLINE_ASCII=1     退回純 ASCII
#   CLAUDE_STATUSLINE_NERDFONT=1  啟用 Nerd Font 圖示
#   CLAUDE_STATUSLINE_POWERLINE=1 啟用 Powerline 分隔符（預設跟隨 NERDFONT）
#   COLORTERM=truecolor|24bit     系統自動設定，啟用真彩色漸層

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# 環境偵測
# ═══════════════════════════════════════════════════════════════

USE_ASCII="${CLAUDE_STATUSLINE_ASCII:-0}"
USE_NERDFONT="${CLAUDE_STATUSLINE_NERDFONT:-0}"
USE_POWERLINE="${CLAUDE_STATUSLINE_POWERLINE:-$USE_NERDFONT}"
USE_TRUECOLOR=0
if [[ "${COLORTERM:-}" == "truecolor" || "${COLORTERM:-}" == "24bit" ]]; then
  USE_TRUECOLOR=1
fi

# ═══════════════════════════════════════════════════════════════
# 色彩與符號
# ═══════════════════════════════════════════════════════════════

RST='\033[0m'
CYAN='\033[36m'
BLUE='\033[34m'
GRAY='\033[90m'
DIM='\033[2m'
YELLOW='\033[33m'
GREEN='\033[32m'
RED='\033[31m'
MAGENTA='\033[35m'

# Anthropic 品牌紫 (#7266EA)
if (( USE_TRUECOLOR )); then
  PURPLE='\033[38;2;114;102;234m'
  BRIGHT_PURPLE='\033[38;2;199;125;255m'
else
  PURPLE='\033[35m'
  BRIGHT_PURPLE='\033[95m'
fi

# 符號集
if [[ "$USE_ASCII" == "1" ]]; then
  S_BRAND="<>"
  S_BRANCH="> "
  S_WARN="!"
  S_PROMPT=">"
  S_TIME=""
  S_EFFORT=""
  SEP=" | "
elif [[ "$USE_NERDFONT" == "1" ]]; then
  S_BRAND="◆"
  S_BRANCH=" "
  S_WARN=" 󰀦"
  S_PROMPT="❯"
  S_TIME="󰔟 "
  S_EFFORT="󰓅 "
  if [[ "$USE_POWERLINE" == "1" ]]; then
    SEP="  "
  else
    SEP=" │ "
  fi
else
  S_BRAND="◆"
  S_BRANCH="⎇ "
  S_WARN=" ⚠"
  S_PROMPT="❯"
  S_TIME=""
  S_EFFORT="⚡"
  if [[ "$USE_POWERLINE" == "1" ]]; then
    SEP="  "
  else
    SEP=" │ "
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 降級輸出
# ═══════════════════════════════════════════════════════════════

fallback_prompt() {
  printf '%b' "${GRAY}${1:-─}${RST}"
  exit 0
}

command -v jq &>/dev/null || fallback_prompt "─ │ jq not found"

# ═══════════════════════════════════════════════════════════════
# 讀取 JSON（單次 jq）
# ═══════════════════════════════════════════════════════════════

input=$(cat)

parsed=$(echo "$input" | jq -r '
  (.model.display_name // ""),
  (.context_window.used_percentage // 0 | tostring),
  (.effort.level // ""),
  (.workspace.current_dir // "." | split("/") | last),
  (.worktree.branch // ""),
  (.rate_limits.five_hour.used_percentage // -1 | tostring),
  (.rate_limits.seven_day.used_percentage // -1 | tostring),
  (.agent.name // ""),
  (.workspace.current_dir // "."),
  (.cost.total_duration_ms // 0 | tostring),
  (.context_window.context_window_size // 0 | tostring),
  (.worktree.name // ""),
  (.rate_limits.five_hour.resets_at // 0 | tostring),
  (.rate_limits.seven_day.resets_at // 0 | tostring),
  (.context_window.total_input_tokens // 0 | tostring),
  (.context_window.total_output_tokens // 0 | tostring),
  (.transcript_path // ""),
  "END"
' 2>/dev/null) || fallback_prompt "─ │ parse error"

{
  IFS= read -r model_name
  IFS= read -r ctx_pct
  IFS= read -r effort
  IFS= read -r dir
  IFS= read -r branch
  IFS= read -r rate5h
  IFS= read -r rate7d
  IFS= read -r agent_name
  IFS= read -r cwd_full
  IFS= read -r duration_ms
  IFS= read -r ctx_size
  IFS= read -r wt_name
  IFS= read -r rate5h_reset_at
  IFS= read -r rate7d_reset_at
  IFS= read -r tok_in
  IFS= read -r tok_out
  IFS= read -r transcript_path
  IFS= read -r _sentinel
} <<< "$parsed"

# ═══════════════════════════════════════════════════════════════
# 模型
# ═══════════════════════════════════════════════════════════════

model="${model_name:-─}"

# ═══════════════════════════════════════════════════════════════
# 上下文進度條
# ═══════════════════════════════════════════════════════════════

pct_int=${ctx_pct%.*}
pct_int=${pct_int:-0}
if (( pct_int < 0 )); then pct_int=0; fi
if (( pct_int > 100 )); then pct_int=100; fi

bar_filled=$(( pct_int / 10 ))
if (( bar_filled > 10 )); then bar_filled=10; fi

# 漸層色（真彩色）：綠 → 黃 → 橘 → 紅
GRAD_R=(46 116 186 241 239 236 233 231 211 192)
GRAD_G=(204 195 186 196 161 126 101 76 66 57)
GRAD_B=(113 89 64 15 24 34 44 60 50 43)

bar=""
if [[ "$USE_ASCII" == "1" ]]; then
  # ASCII 模式
  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then bar+="#"; else bar+="-"; fi
  done
elif (( USE_TRUECOLOR )); then
  # 真彩色漸層：每格獨立上色
  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then
      bar+="\\033[38;2;${GRAD_R[$i]};${GRAD_G[$i]};${GRAD_B[$i]}m█"
    else
      bar+="\\033[38;2;60;60;60m░"
    fi
  done
  bar+="${RST}"
else
  # ANSI 退回：依整體百分比選色
  if (( pct_int >= 90 )); then bar_color="$RED"
  elif (( pct_int >= 70 )); then bar_color="$YELLOW"
  else bar_color="$GREEN"; fi

  for (( i=0; i<10; i++ )); do
    if (( i < bar_filled )); then bar+="█"; else bar+="░"; fi
  done
  bar="${bar_color}${bar}${RST}"
fi

# 百分比文字顏色（跟進度條整體色一致）
if (( pct_int >= 90 )); then pct_color="$RED"
elif (( pct_int >= 70 )); then pct_color="$YELLOW"
else pct_color="$GREEN"; fi

# 警告符號
ctx_warn=""
if (( pct_int >= 90 )); then ctx_warn="${RED}${S_WARN}${RST}"; fi

# 上下文視窗大小（僅在 model display_name 不包含 context 資訊時才顯示）
ctx_size_int=${ctx_size:-0}
ctx_label=""
if [[ "$model" != *context* && "$model" != *Context* ]]; then
  if (( ctx_size_int >= 1000000 )); then ctx_label=" ${GRAY}1M${RST}"
  elif (( ctx_size_int >= 200000 )); then ctx_label=" ${GRAY}200k${RST}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 推理強度 effort（條件顯示，僅模型支援時 JSON 才帶 .effort.level）
# ═══════════════════════════════════════════════════════════════

effort="${effort:-}"
effort_section=""
if [[ -n "$effort" ]]; then
  # 強度越高顏色越警示：max/xhigh 紅、high 黃、其餘灰
  case "$effort" in
    max|xhigh) effort_color="$RED" ;;
    high)      effort_color="$YELLOW" ;;
    *)         effort_color="$GRAY" ;;
  esac
  effort_section="${SEP}${effort_color}${S_EFFORT}${effort}${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# Token 用量（In: 輸入 / Out: 輸出，本 session 全程累計，零值智慧隱藏）
# ═══════════════════════════════════════════════════════════════
#
# context_window.total_* 自 v2.1.132 起只反映「當前上下文快照」而非整個
# session 累計，因此這裡改為解析 transcript（JSONL）把每次 API 回應的 usage
# 加總起來，得到真正的 session 全程消耗值。以 transcript mtime 為鍵做快取，
# 內容沒變就不重算；無法讀取 transcript 時退回 context_window 快照。

# 人類可讀格式：1234→1.2k、1234567→1.2M
format_tokens() {
  local n=$1
  if (( n >= 1000000 )); then
    printf '%d.%dM' $(( n / 1000000 )) $(( (n % 1000000) / 100000 ))
  elif (( n >= 1000 )); then
    printf '%d.%dk' $(( n / 1000 )) $(( (n % 1000) / 100 ))
  else
    printf '%d' "$n"
  fi
}

file_mtime() {
  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f %m "$1" 2>/dev/null || echo 0
  else
    stat -c %Y "$1" 2>/dev/null || echo 0
  fi
}

# 預設：退回 context_window 快照
tok_in=${tok_in:-0}
tok_out=${tok_out:-0}

if [[ -n "${transcript_path:-}" && -f "$transcript_path" ]]; then
  tp_mtime=$(file_mtime "$transcript_path")
  tp_key=$(printf '%s' "$transcript_path" | cksum | cut -d' ' -f1)
  TOKEN_CACHE="/tmp/claude-statusline-tokens-${tp_key}"

  cache_mtime=""; cache_in=""; cache_out=""
  if [[ -f "$TOKEN_CACHE" ]]; then
    IFS='|' read -r cache_mtime cache_in cache_out < "$TOKEN_CACHE" || true
  fi

  if [[ "$cache_mtime" == "$tp_mtime" && -n "$cache_in" ]]; then
    tok_in="$cache_in"
    tok_out="$cache_out"
  else
    # 串流逐行加總（jq -n inputs，不一次載入整個檔案）
    sums=$(jq -n -r '
      reduce inputs as $l ({i:0, o:0};
        ($l.message.usage // null) as $u
        | if $u then
            { i: (.i + ($u.input_tokens // 0)
                     + ($u.cache_creation_input_tokens // 0)
                     + ($u.cache_read_input_tokens // 0)),
              o: (.o + ($u.output_tokens // 0)) }
          else . end)
      | "\(.i) \(.o)"
    ' "$transcript_path" 2>/dev/null) || sums=""
    if [[ -n "$sums" ]]; then
      tok_in="${sums% *}"
      tok_out="${sums#* }"
      printf '%s|%s|%s\n' "$tp_mtime" "$tok_in" "$tok_out" > "$TOKEN_CACHE" 2>/dev/null || true
    fi
  fi
fi

tokens_section=""
if (( tok_in > 0 || tok_out > 0 )); then
  tokens_section="${SEP}${GRAY}In:$(format_tokens "$tok_in") Out:$(format_tokens "$tok_out")${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# 經過時間（零值智慧隱藏）
# ═══════════════════════════════════════════════════════════════

dur_ms=${duration_ms:-0}
dur_section=""
if (( dur_ms > 0 )); then
  dur_sec=$((dur_ms / 1000))
  dur_d=$((dur_sec / 86400))
  dur_h=$(((dur_sec % 86400) / 3600))
  dur_min=$(((dur_sec % 3600) / 60))
  dur_s=$((dur_sec % 60))
  # 格式化後仍為 0m0s 就不顯示（session 啟動初期 dur_ms 可能是幾百毫秒）
  if (( dur_d > 0 || dur_h > 0 || dur_min > 0 || dur_s > 0 )); then
    dur_fmt=""
    (( dur_d > 0 )) && dur_fmt+="${dur_d}d"
    (( dur_h > 0 )) && dur_fmt+="${dur_h}h"
    (( dur_min > 0 )) && dur_fmt+="${dur_min}m"
    dur_fmt+="${dur_s}s"
    dur_section="${SEP}${GRAY}${S_TIME}${dur_fmt}${RST}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# Git 分支與髒標記（帶快取）
# ═══════════════════════════════════════════════════════════════

GIT_CACHE="/tmp/claude-statusline-git-cache"
GIT_CACHE_MAX_AGE=5

git_branch="${branch:-}"
dirty=""

git_cache_is_stale() {
  [[ ! -f "$GIT_CACHE" ]] && return 0
  local mtime
  if [[ "$(uname)" == "Darwin" ]]; then
    mtime=$(stat -f %m "$GIT_CACHE" 2>/dev/null || echo 0)
  else
    mtime=$(stat -c %Y "$GIT_CACHE" 2>/dev/null || echo 0)
  fi
  local cache_age=$(( $(date +%s) - mtime ))
  (( cache_age > GIT_CACHE_MAX_AGE ))
}

if [[ -n "${cwd_full:-}" && -d "${cwd_full:-}" ]]; then
  if git_cache_is_stale; then
    if git -C "$cwd_full" rev-parse --git-dir &>/dev/null; then
      cached_branch="${git_branch}"
      if [[ -z "$cached_branch" ]]; then
        cached_branch=$(git -C "$cwd_full" -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null) || true
        if [[ -z "$cached_branch" ]]; then
          cached_branch=$(git -C "$cwd_full" rev-parse --short HEAD 2>/dev/null) || true
        fi
      fi
      cached_dirty=""
      if ! git -C "$cwd_full" -c core.useBuiltinFSMonitor=false diff --quiet 2>/dev/null || \
         ! git -C "$cwd_full" -c core.useBuiltinFSMonitor=false diff --cached --quiet 2>/dev/null; then
        cached_dirty="*"
      fi
      echo "${cached_branch}|${cached_dirty}" > "$GIT_CACHE"
    else
      echo "|" > "$GIT_CACHE"
    fi
  fi

  if [[ -f "$GIT_CACHE" ]]; then
    IFS='|' read -r cached_br cached_dt < "$GIT_CACHE"
    if [[ -z "$git_branch" ]]; then git_branch="${cached_br}"; fi
    dirty="${cached_dt}"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# 速率限制（條件顯示，含重置倒計時）
# ═══════════════════════════════════════════════════════════════

rate_section=""
rate5h_int=${rate5h%.*}; rate5h_int=${rate5h_int:-0}
rate7d_int=${rate7d%.*}; rate7d_int=${rate7d_int:-0}

# 倒計時：直接用 JSON 裡的 resets_at epoch
now_epoch=$(date +%s)

format_remaining_hm() {
  local rem=$1
  if (( rem <= 0 )); then echo "now"; return; fi
  local h=$(( rem / 3600 ))
  local m=$(( (rem % 3600) / 60 ))
  if (( h > 0 )); then echo "${h}h${m}m"; else echo "${m}m"; fi
}

format_remaining_dhm() {
  local rem=$1
  if (( rem <= 0 )); then echo "now"; return; fi
  local d=$(( rem / 86400 ))
  local h=$(( (rem % 86400) / 3600 ))
  local m=$(( (rem % 3600) / 60 ))
  echo "${d}d${h}h${m}m"
}

rate5h_eta=""
rate7d_eta=""
if (( rate5h_int > 0 && ${rate5h_reset_at:-0} > 0 )); then
  rate5h_eta=$(format_remaining_hm $(( rate5h_reset_at - now_epoch )))
fi
if (( rate7d_int > 0 && ${rate7d_reset_at:-0} > 0 )); then
  rate7d_eta=$(format_remaining_dhm $(( rate7d_reset_at - now_epoch )))
fi

rate_parts=""
if (( rate5h_int >= 0 )); then
  if (( rate5h_int >= 80 )); then rc="$RED"; else rc="$GRAY"; fi
  if [[ -n "$rate5h_eta" ]]; then
    rate_parts+="${rc}5h:${rate5h_int}%(↺ ${rate5h_eta})${RST}"
  else
    rate_parts+="${rc}5h:${rate5h_int}%${RST}"
  fi
fi
if (( rate7d_int >= 0 )); then
  if [[ -n "$rate_parts" ]]; then rate_parts+=" "; fi
  if (( rate7d_int >= 80 )); then rc="$RED"; else rc="$GRAY"; fi
  if [[ -n "$rate7d_eta" ]]; then
    rate_parts+="${rc}7d:${rate7d_int}%(↺ ${rate7d_eta})${RST}"
  else
    rate_parts+="${rc}7d:${rate7d_int}%${RST}"
  fi
fi
if [[ -n "$rate_parts" ]]; then
  rate_section="${SEP}${rate_parts}"
fi

# ═══════════════════════════════════════════════════════════════
# 動態提示符（顏色跟上下文用量連動）
# ═══════════════════════════════════════════════════════════════

if (( pct_int >= 90 )); then prompt_color="$RED"
elif (( pct_int >= 70 )); then prompt_color="$YELLOW"
else prompt_color="$GREEN"; fi

# ═══════════════════════════════════════════════════════════════
# 組裝（第一行：模型/進度/effort/token/時間/速率；第二行：分支/目錄/指示器）
# ═══════════════════════════════════════════════════════════════

line1="${PURPLE}${S_BRAND}${RST} ${CYAN}${model}${RST}"
line1+="${SEP}${bar} ${pct_color}${pct_int}%${RST}${ctx_warn}${ctx_label}"
line1+="${effort_section}"
line1+="${tokens_section}"
line1+="${dur_section}"
line1+="${rate_section}"

line2=""
if [[ -n "$git_branch" ]]; then
  line2+="${BRIGHT_PURPLE}${S_BRANCH}${git_branch}${dirty}${RST}${SEP}"
fi
line2+="${BRIGHT_PURPLE}${dir}${RST}"

# Agent / Worktree 指示器（僅在非主 session 時顯示）
if [[ -n "${wt_name:-}" ]]; then
  line2+="${SEP}${YELLOW}⚙ worktree:${wt_name}${RST}"
elif [[ -n "${agent_name:-}" ]]; then
  line2+="${SEP}${YELLOW}⚙ ${agent_name}${RST}"
fi

# ═══════════════════════════════════════════════════════════════
# 輸出
# ═══════════════════════════════════════════════════════════════

printf '%b\n%b' "$line1" "$line2"

