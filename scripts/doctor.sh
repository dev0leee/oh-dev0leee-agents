#!/usr/bin/env bash
# 진단만 한다. 아무것도 고치지 않는다.
#
#   ./scripts/doctor.sh
#
# "설정이 존재한다" 와 "실제로 인증돼 동작한다" 는 다른 상태라서 구분해 보여준다.
#
# 종료 코드: 문제 0 건이면 0, 하나라도 있으면 1.
# CI 나 `./scripts/doctor.sh && ...` 에서 판정할 수 있게 하기 위한 것이다.
# install.sh 는 `|| true` 로 감싸 호출하므로 설치 흐름은 끊기지 않는다.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

PROBLEMS=0
note() { printf '  %s?%s %s\n' "$C_DIM" "$C_OFF" "$*"; }
bad()  { PROBLEMS=$((PROBLEMS+1)); err "$*"; }

# ─────────────────────────────────────────────── Configuration
printf '\n%s\n' "Configuration"

for cmd in claude codex jq python3 node git; do
  if have "$cmd"; then
    ok "$cmd 설치됨"
  elif [ "$cmd" = "codex" ] || [ "$cmd" = "claude" ]; then
    bad "$cmd 없음"
  else
    bad "$cmd 없음 (설치 필요)"
  fi
done

check_link() {
  local repo_rel="$1" dst="$2"
  local want="$REPO/$repo_rel"
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    bad "$dst 없음 — ./scripts/install.sh 실행"
  elif [ ! -L "$dst" ]; then
    bad "$dst 가 심볼릭 링크가 아닌 일반 파일이다 — ./scripts/install.sh 실행"
  elif [ "$(realpath "$dst" 2>/dev/null)" != "$(realpath "$want" 2>/dev/null)" ]; then
    bad "$dst 가 엉뚱한 곳을 가리킨다: $(realpath "$dst" 2>/dev/null)"
  else
    ok "$dst -> $repo_rel"
  fi
}

check_link instructions/CLAUDE.md     "$CLAUDE_DIR/CLAUDE.md"
check_link instructions/AGENTS.md     "$CODEX_DIR/AGENTS.md"
check_link claude/omc-config.json     "$CLAUDE_DIR/.omc-config.json"
check_link claude/hud/omc-hud-min.mjs "$CLAUDE_DIR/hud/omc-hud-min.mjs"
for dir in "$REPO"/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  check_link "skills/$name" "$CLAUDE_DIR/skills/$name"
  check_link "skills/$name" "$CODEX_DIR/skills/$name"
done

for f in "$CLAUDE_DIR/CLAUDE.md" "$CODEX_DIR/AGENTS.md"; do
  if [ -s "$f" ]; then
    ok "$(basename "$f") 내용 있음 ($(wc -l < "$f" | tr -d ' ') 줄)"
  else
    bad "$(basename "$f") 가 비어 있다"
  fi
done

load_env
for var in EXA_API_KEY FILESYSTEM_DIR; do
  if [ -n "${!var:-}" ]; then
    ok "$var 설정됨"
  else
    note "$var 미설정 — 관련 MCP 서버는 등록되지 않는다 (.env.local)"
  fi
done

printf '\n'
if have claude; then
  log "  Claude MCP:"
  python3 "$REPO/scripts/mcp_reconcile.py" --tool claude --dry-run 2>&1 | sed 's/^/  /'
fi
if have codex; then
  log "  Codex MCP:"
  python3 "$REPO/scripts/mcp_reconcile.py" --tool codex --dry-run 2>&1 | sed 's/^/  /'
fi

# ─────────────────────────────────────────────── Authentication
printf '\n%s\n' "Authentication"
# 토큰의 "존재 여부"만 본다. 값은 절대 읽지도 출력하지도 않는다.
python3 - <<'PY'
import json, os, subprocess, sys

def say(sym, msg): print(f"  {sym} {msg}")

try:
    with open(os.path.expanduser("~/.claude.json"), encoding="utf-8") as fh:
        servers = (json.load(fh).get("mcpServers") or {})
except (OSError, ValueError):
    servers = {}

for name, cfg in sorted(servers.items()):
    if cfg.get("type") == "http" or cfg.get("url"):
        if (cfg.get("headers") or {}).get("Authorization"):
            say("✓", f'Claude MCP "{name}" 인증 토큰 있음')
        else:
            say("!", f'Claude MCP "{name}" 인증 필요 — claude 실행 후 /mcp 에서 로그인')

try:
    res = subprocess.run(["codex", "mcp", "list", "--json"],
                         capture_output=True, text=True, timeout=60)
    entries = json.loads(res.stdout) if res.returncode == 0 else []
except Exception:
    entries = []

for e in entries:
    status = e.get("auth_status")
    if status == "not_logged_in":
        say("!", f'Codex MCP "{e["name"]}" 로그인 필요')
    elif status not in (None, "unsupported"):
        say("✓", f'Codex MCP "{e["name"]}" {status}')
PY

if have codex; then
  if codex doctor --help 2>/dev/null | grep -q -- '--summary'; then
    codex doctor --summary 2>&1 | sed 's/^/  /' | head -20
  else
    codex doctor 2>&1 | sed 's/^/  /' | head -20
  fi
fi

# ─────────────────────────────────────────────── Connectivity
printf '\n%s\n' "Connectivity"
note "실제 연결 테스트는 하지 않는다 (서버를 띄우고 인증을 소모하므로)"
note "확인하려면: claude mcp list  /  codex mcp list"

# ─────────────────────────────────────────────── 요약
printf '\n'
if [ "$PROBLEMS" -eq 0 ]; then
  ok "문제 없음"
  exit 0
else
  err "문제 $PROBLEMS 건"
  exit 1
fi
