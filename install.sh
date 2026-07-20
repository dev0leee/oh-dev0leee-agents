#!/usr/bin/env bash
# install.sh — 이 저장소의 Claude Code 설정을 새 PC에 복원한다.
# 사용법: bash install.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

echo "==> Claude 설정 디렉터리: $CLAUDE_DIR"
mkdir -p "$CLAUDE_DIR"

backup() {
  local target="$1"
  if [ -f "$target" ]; then
    cp "$target" "${target}.bak.$(date +%s)"
    echo "    기존 파일 백업: ${target}.bak.*"
  fi
}

echo "==> 전역 설정 파일 복사"
backup "$CLAUDE_DIR/CLAUDE.md";        cp "$REPO_DIR/config/CLAUDE.md"       "$CLAUDE_DIR/CLAUDE.md"
backup "$CLAUDE_DIR/settings.json";    cp "$REPO_DIR/config/settings.json"   "$CLAUDE_DIR/settings.json"
backup "$CLAUDE_DIR/.omc-config.json"; cp "$REPO_DIR/config/omc-config.json" "$CLAUDE_DIR/.omc-config.json"

echo ""
echo "==> MCP 서버 등록"
# 우선순위: .env.local > .env (둘 다 gitignore 됨)
ENV_FILE=""
[ -f "$REPO_DIR/.env" ] && ENV_FILE="$REPO_DIR/.env"
[ -f "$REPO_DIR/.env.local" ] && ENV_FILE="$REPO_DIR/.env.local"
if [ -n "$ENV_FILE" ]; then
  echo "    키 파일: $ENV_FILE"
  set -a; . "$ENV_FILE"; set +a
  if command -v claude >/dev/null 2>&1; then
    claude mcp add context7 -- npx -y @upstash/context7-mcp || true
    if [ -n "${FILESYSTEM_DIR:-}" ]; then
      claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem "$FILESYSTEM_DIR" || true
    else
      echo "    (FILESYSTEM_DIR 미설정 → filesystem 건너뜀)"
    fi
    if [ -n "${EXA_API_KEY:-}" ]; then
      claude mcp add exa -e "EXA_API_KEY=$EXA_API_KEY" -- npx -y exa-mcp-server || true
    else
      echo "    (EXA_API_KEY 미설정 → exa 건너뜀)"
    fi
    claude mcp add --transport http github https://api.githubcopilot.com/mcp/ || true
  else
    echo "    claude CLI 없음 → MCP 등록 건너뜀. mcp/mcp-servers.md 참고."
  fi
else
  echo "    .env.local / .env 없음 → MCP 자동 등록 생략."
  echo "    'cp .env.example .env.local' 후 키를 채우고 다시 실행하거나, mcp/mcp-servers.md 참고."
fi

echo ""
echo "완료. 남은 수동 단계:"
echo "  1) OMC 플러그인 설치:  claude /plugin install oh-my-claudecode"
echo "  2) HUD/셋업 마무리:    claude 실행 후  /oh-my-claudecode:omc-setup"
echo "  3) GitHub MCP 인증:    claude 에서 /mcp → github 선택 후 로그인"
echo "  4) Claude Code 재시작 (HUD 상태줄 반영)"
