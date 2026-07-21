#!/usr/bin/env bash
# 설치 스크립트 공용 함수. 단독 실행하지 않고 source 해서 쓴다.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

ASSUME_YES=0   # --yes 가 넘어오면 1
DRY_RUN=0      # --dry-run 이 넘어오면 1. 이 값을 보는 함수는 아무것도 바꾸지 않는다.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_ERR=''; C_DIM=''; C_OFF=''
fi

log()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
ok()   { printf '  %s✓%s %s\n' "$C_OK" "$C_OFF" "$*"; }
skip() { printf '  %s·%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_WARN" "$C_OFF" "$*" >&2; }
err()  { printf '  %s✗%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; }
die()  { err "$*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# 확인 프롬프트. --yes 면 통과시키되 경고는 남긴다.
confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" -eq 1 ]; then
    warn "$prompt → --yes 로 자동 승인"
    return 0
  fi
  if [ ! -t 0 ]; then
    warn "$prompt → 대화형 입력이 불가능해 건너뜀 (--yes 로 강제 가능)"
    return 1
  fi
  local reply
  printf '  %s? %s [y/N] ' "$C_WARN$C_OFF" "$prompt"
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

backup() {
  local target="$1"
  [ -e "$target" ] || return 0
  [ -L "$target" ] && return 0   # 링크는 백업하지 않는다
  local dest="${target}.bak.$(date +%Y%m%d-%H%M%S)"
  if [ "$DRY_RUN" -eq 1 ]; then
    warn "(dry-run) 백업했을 것: $dest"
    return 0
  fi
  cp -p "$target" "$dest"
  warn "기존 파일 백업: $dest"
}

# link_file <레포내_경로> <홈_경로>
# 이미 올바른 링크면 아무것도 하지 않는다(재실행해도 백업이 쌓이지 않는다).
link_file() {
  local src="$REPO/$1" dst="$2" label="${3:-$2}"
  [ -e "$src" ] || { err "원본이 없다: $src"; return 1; }
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    local cur
    cur="$(cd "$(dirname "$dst")" && realpath "$dst" 2>/dev/null || true)"
    if [ "$cur" = "$(realpath "$src")" ]; then
      skip "$label (이미 연결됨)"
      return 0
    fi
    warn "$label 이 다른 곳을 가리키고 있어 교체한다: $cur"
    [ "$DRY_RUN" -eq 1 ] || rm "$dst"
  elif [ -e "$dst" ]; then
    backup "$dst"
    [ "$DRY_RUN" -eq 1 ] || rm -rf "$dst"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    skip "(dry-run) $label -> $1"
    return 0
  fi
  ln -sfn "$src" "$dst"
  ok "$label -> $1"
}

# .env.local > .env 순으로 읽는다. 둘 다 gitignore 대상.
load_env() {
  local f
  for f in "$REPO/.env" "$REPO/.env.local"; do
    if [ -f "$f" ]; then
      set -a; . "$f"; set +a
      skip "환경변수 로드: $(basename "$f")"
    fi
  done
}

# 인자로 받은 CLI 가 해당 플래그를 지원하는지 확인한다.
# 특정 버전에 스크립트가 묶이지 않게 하기 위한 것.
supports_flag() {
  local cmd="$1"; shift
  local sub=() flag="${!#}"
  local i
  for ((i=1; i<$#; i++)); do sub+=("${!i}"); done
  "$cmd" "${sub[@]}" --help 2>/dev/null | grep -q -- "$flag"
}
