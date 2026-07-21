#!/usr/bin/env bash
# 새 프로젝트에 AGENTS.md / CLAUDE.md 시작 세트를 복사한다.
#
#   ./scripts/init-project.sh ~/projects/my-app [--force]
#
# 기본은 "기존 파일을 건드리지 않는다". 이미 있으면 건너뛰고 경고만 낸다.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

FORCE=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    -h|--help) echo "사용법: init-project.sh <프로젝트_경로> [--force]"; exit 0 ;;
    *) [ -z "$TARGET" ] && TARGET="$arg" || die "인자가 너무 많다: $arg" ;;
  esac
done
[ -n "$TARGET" ] || die "프로젝트 경로를 지정해야 한다. 예: ./scripts/init-project.sh ~/projects/my-app"

TARGET="${TARGET/#\~/$HOME}"
[ -d "$TARGET" ] || die "디렉터리가 없다: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"

case "$TARGET/" in
  "$REPO/"*) die "이 레포 자신에는 적용하지 않는다: $TARGET" ;;
esac

SRC="$REPO/templates/project"
[ -d "$SRC" ] || die "템플릿이 없다: $SRC"

step "템플릿 복사: $SRC -> $TARGET"
copied=0; skipped=0

while IFS= read -r rel; do
  src="$SRC/$rel"
  dst="$TARGET/$rel"
  if [ -e "$dst" ] && [ "$FORCE" -eq 0 ]; then
    warn "이미 있어 건너뜀: $rel  (덮어쓰려면 --force)"
    skipped=$((skipped+1))
    continue
  fi
  mkdir -p "$(dirname "$dst")"
  [ -e "$dst" ] && backup "$dst"
  cp "$src" "$dst"
  ok "$rel"
  copied=$((copied+1))
done < <(cd "$SRC" && find . -type f | sed 's|^\./||' | sort)

log ""
log "복사 $copied 건, 건너뜀 $skipped 건"
cat <<EOF

다음에 할 것:
  1) $TARGET/AGENTS.md 의 <> 부분을 이 프로젝트에 맞게 채운다
     (빌드/테스트 명령, 디렉터리 규칙, 건드리면 안 되는 파일)
  2) Claude 에만 필요한 내용이 있으면 CLAUDE.md 에 적는다
     공통 내용은 AGENTS.md 한 곳에만 두는 편이 관리하기 쉽다
  3) 프로젝트 전용 권한/훅이 필요하면 .claude/settings.json 을 손본다
EOF
