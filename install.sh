#!/usr/bin/env bash
# install.sh — 이 저장소의 Claude Code 설정(플러그인 + MCP + 전역설정)을 새 PC에 복원한다.
# 사용법:
#   cp .env.example .env.local   # 키 채우기
#   bash install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HAS_CLAUDE=0; command -v claude >/dev/null 2>&1 && HAS_CLAUDE=1

echo "==> Claude 설정 디렉터리: $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR"

backup() {
  local target="$1"
  if [ -f "$target" ]; then
    cp "$target" "${target}.bak.$(date +%s)"
    echo "    기존 파일 백업: ${target}.bak.*"
  fi
}

# ── 1. 전역 설정 파일 ─────────────────────────────────────────────
echo "==> [1/4] 전역 설정 파일 복사"
backup "$CLAUDE_DIR/CLAUDE.md";        cp "$REPO_DIR/config/CLAUDE.md"       "$CLAUDE_DIR/CLAUDE.md"
backup "$CLAUDE_DIR/settings.json";    cp "$REPO_DIR/config/settings.json"   "$CLAUDE_DIR/settings.json"
backup "$CLAUDE_DIR/.omc-config.json"; cp "$REPO_DIR/config/omc-config.json" "$CLAUDE_DIR/.omc-config.json"

# ── 2. 마켓플레이스 + 플러그인 ────────────────────────────────────
echo ""
echo "==> [2/4] 마켓플레이스 + 플러그인 설치"
if [ "$HAS_CLAUDE" -eq 1 ]; then
  claude plugin marketplace add anthropics/claude-plugins-official || true
  claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode.git || true
  claude plugin install oh-my-claudecode@omc -s user || true
else
  echo "    claude CLI 없음 → 수동: /plugin 에서 omc 마켓 추가 후 oh-my-claudecode 설치"
fi

# ── 3. MCP 서버 (전역/user 스코프) ────────────────────────────────
echo ""
echo "==> [3/4] MCP 서버 등록 (user 스코프 = 모든 프로젝트에서 사용)"
# 키는 .env.local > .env 순으로 로드 (둘 다 gitignore 됨)
ENV_FILE=""
[ -f "$REPO_DIR/.env" ]       && ENV_FILE="$REPO_DIR/.env"
[ -f "$REPO_DIR/.env.local" ] && ENV_FILE="$REPO_DIR/.env.local"
[ -n "$ENV_FILE" ] && { echo "    키 파일: $ENV_FILE"; set -a; . "$ENV_FILE"; set +a; }

if [ "$HAS_CLAUDE" -eq 1 ]; then
  # 키 불필요
  claude mcp add -s user context7 -- npx -y @upstash/context7-mcp || true
  claude mcp add -s user --transport http lazyweb https://www.lazyweb.com/mcp || true
  claude mcp add -s user --transport http github https://api.githubcopilot.com/mcp/ || true
  # 값 필요
  if [ -n "${FILESYSTEM_DIR:-}" ]; then
    claude mcp add -s user filesystem -- npx -y @modelcontextprotocol/server-filesystem "$FILESYSTEM_DIR" || true
  else
    echo "    (FILESYSTEM_DIR 미설정 → filesystem 건너뜀)"
  fi
  if [ -n "${EXA_API_KEY:-}" ]; then
    claude mcp add -s user exa -e "EXA_API_KEY=$EXA_API_KEY" -- npx -y exa-mcp-server || true
  else
    echo "    (EXA_API_KEY 미설정 → exa 건너뜀. .env.local 채우고 재실행)"
  fi
else
  echo "    claude CLI 없음 → mcp/mcp-servers.md 참고해 수동 등록"
fi

# ── 4. 안내 ───────────────────────────────────────────────────────
echo ""
echo "==> [4/4] 완료. 남은 수동 단계:"
echo "  1) Claude Code 재시작 (플러그인/HUD 상태줄 반영)"
echo "  2) OMC 셋업 마무리:  claude 실행 후  /oh-my-claudecode:omc-setup"
echo "  3) GitHub MCP 인증:  /mcp → github 선택 후 로그인 (HTTP OAuth)"
echo "  4) lazyweb 인증:     최초 사용 시 로그인 안내가 나오면 따르기"
echo ""
echo "확인:  claude mcp list   /   claude plugin list"
