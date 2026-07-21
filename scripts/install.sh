#!/usr/bin/env bash
# 진입점. Claude + Codex 설정을 설치하고 마지막에 진단을 돌린다.
#
#   ./scripts/install.sh [--claude-only|--codex-only] [--unrestricted] [--yes] [--dry-run]
#
# 개별 설치가 필요하면 install-claude.sh / install-codex.sh 를 직접 부르면 된다.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"

DO_CLAUDE=1
DO_CODEX=1
passthru=()
codex_only_args=()

for arg in "$@"; do
  case "$arg" in
    --claude-only)  DO_CODEX=0 ;;
    --codex-only)   DO_CLAUDE=0 ;;
    --unrestricted) codex_only_args+=("$arg") ;;   # codex 에만 의미가 있다
    --yes|-y|--dry-run) passthru+=("$arg") ;;
    *) die "알 수 없는 옵션: $arg" ;;
  esac
done

log "레포:   $REPO"
log "Claude: $CLAUDE_DIR"
log "Codex:  $CODEX_DIR"

if [ "$DO_CLAUDE" -eq 1 ]; then
  printf '\n%s\n' "──────── Claude Code ────────"
  "$HERE/install-claude.sh" ${passthru[@]+"${passthru[@]}"}
fi

if [ "$DO_CODEX" -eq 1 ]; then
  printf '\n%s\n' "──────── Codex CLI ────────"
  "$HERE/install-codex.sh" ${passthru[@]+"${passthru[@]}"} ${codex_only_args[@]+"${codex_only_args[@]}"}
fi

printf '\n%s\n' "──────── 시크릿 검사 훅 ────────"
# 이 레포에만 건다. 전역 적용은 install-gitleaks.sh --global 로 따로.
"$HERE/install-gitleaks.sh" ${passthru[@]+"${passthru[@]}"}

printf '\n%s\n' "──────── 진단 ────────"
"$HERE/doctor.sh" || true

cat <<'EOF'

수동으로 해야 하는 것:
  1) Claude 로그인       claude  (최초 1회)
  2) Codex 로그인        codex login
  3) Lazyweb MCP 인증    최초 사용 시 안내를 따를 것
  4) API 키              cp .env.example .env.local 후 값 입력, 그리고 재실행
EOF
