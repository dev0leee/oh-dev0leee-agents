#!/usr/bin/env bash
# gitleaks pre-commit 훅을 설치한다.
#   ./scripts/install-gitleaks.sh [--global] [--yes] [--dry-run]
#
#   기본     이 레포에만 훅을 건다 (core.hooksPath=.githooks).
#   --global 홈에도 훅을 깔아 앞으로 만드는 모든 레포에 적용한다.
#            전역 core.hooksPath 를 켜면 기존 레포의 .git/hooks/ 가 무시되므로
#            적용 전에 확인을 받는다.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN=0
GLOBAL=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)  ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --global)  GLOBAL=1 ;;
    *) die "알 수 없는 옵션: $arg" ;;
  esac
done

GLOBAL_HOOKS="${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks"

step "[1/3] gitleaks 바이너리"
if have gitleaks; then
  skip "gitleaks $(gitleaks version 2>/dev/null) (이미 설치됨)"
elif [ "$DRY_RUN" -eq 1 ]; then
  skip "(dry-run) brew install gitleaks"
elif have brew && confirm "gitleaks 가 없다. brew 로 설치할까?"; then
  brew install gitleaks
  ok "gitleaks 설치"
else
  warn "gitleaks 미설치 — 훅은 깔되 커밋 시 설치하라는 에러가 난다."
fi

step "[2/3] 이 레포 훅"
# 훅 파일이 레포에 있으므로 clone 만 해도 따라온다. hooksPath 연결만 해주면 된다.
if [ "$(git -C "$REPO" config --local core.hooksPath || true)" = ".githooks" ]; then
  skip "core.hooksPath (이미 .githooks)"
elif [ "$DRY_RUN" -eq 1 ]; then
  skip "(dry-run) git config core.hooksPath .githooks"
else
  git -C "$REPO" config --local core.hooksPath .githooks
  ok "core.hooksPath -> .githooks"
fi
[ "$DRY_RUN" -eq 1 ] || chmod +x "$REPO/.githooks/pre-commit"

step "[3/3] 전역 훅"
if [ "$GLOBAL" -eq 0 ]; then
  skip "건너뜀 (--global 로 켤 수 있다)"
else
  link_file .githooks/pre-commit "$GLOBAL_HOOKS/pre-commit" "~/.config/git/hooks/pre-commit"

  cur="$(git config --global core.hooksPath || true)"
  if [ "$cur" = "$GLOBAL_HOOKS" ]; then
    skip "전역 core.hooksPath (이미 설정됨)"
  elif [ -n "$cur" ]; then
    warn "전역 core.hooksPath 가 이미 다른 곳을 가리킨다: $cur — 건드리지 않는다."
  elif [ "$DRY_RUN" -eq 1 ]; then
    skip "(dry-run) git config --global core.hooksPath $GLOBAL_HOOKS"
  else
    warn "전역 core.hooksPath 를 켜면 기존 레포의 .git/hooks/ 안 훅들이 무시된다."
    warn "(husky 처럼 레포별로 core.hooksPath 를 따로 잡는 도구는 영향 없다)"
    if confirm "전역 core.hooksPath 를 $GLOBAL_HOOKS 로 설정할까?"; then
      git config --global core.hooksPath "$GLOBAL_HOOKS"
      ok "전역 core.hooksPath -> $GLOBAL_HOOKS"
    else
      log "  건너뜀. 이 레포에만 적용된다."
    fi
  fi
fi

log ""
ok "gitleaks 훅 설치 완료"
log "   전체 히스토리 검사: gitleaks git . --redact"
log "   훅 우회(비권장):    git commit --no-verify"
