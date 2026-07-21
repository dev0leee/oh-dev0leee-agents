#!/usr/bin/env bash
# 홈에 이미 있는 설정 파일을 이 레포로 옮기고 그 자리에 심볼릭 링크를 건다.
#
#   ./scripts/adopt.sh ~/.claude/skills/worktree skills/worktree
#
# 되돌리기 어려운 동작(파일 이동)이라 아래 검사를 모두 통과해야 실행된다.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
사용법: adopt.sh <홈_경로> <레포_상대경로> [--yes]

  홈_경로        레포로 흡수할 실제 파일 또는 디렉터리
  레포_상대경로  레포 안에서 보관할 위치 (레포 루트 기준)
EOF
  exit 1
}

SRC=""; DEST_REL=""
for arg in "$@"; do
  case "$arg" in
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) usage ;;
    *) if [ -z "$SRC" ]; then SRC="$arg"; elif [ -z "$DEST_REL" ]; then DEST_REL="$arg"; else usage; fi ;;
  esac
done
[ -n "$SRC" ] && [ -n "$DEST_REL" ] || usage

# ── 안전장치 ──────────────────────────────────────────────────────
SRC="${SRC/#\~/$HOME}"

# 1. source 가 존재하는가 / 이미 링크인가
[ -e "$SRC" ] || die "원본이 없다: $SRC"
[ -L "$SRC" ] && die "이미 심볼릭 링크다(흡수 완료로 보인다): $SRC"

SRC_ABS="$(cd "$(dirname "$SRC")" && pwd -P)/$(basename "$SRC")"
SRC_ABS="${SRC_ABS%/}"          # 후행 슬래시 제거
[ -n "$SRC_ABS" ] && SRC_ABS="${SRC_ABS:-/}"

# 2. source 가 이미 레포 안이면 옮길 이유가 없다
case "$SRC_ABS/" in
  "$REPO/"*) die "원본이 이미 레포 안이다: $SRC_ABS" ;;
esac

# 3. 홈 밖은 흡수하지 않는다. "/" 나 /etc 같은 시스템 경로를 한 번에 걸러낸다.
#    (주의: "${guard%/}" 로 비교하면 "/" 가 빈 문자열이 돼 가드가 통째로 무력화된다)
case "$SRC_ABS/" in
  "$HOME"/*) ;;
  *) die "홈 디렉터리 밖은 흡수하지 않는다: $SRC_ABS" ;;
esac

# 4. 디렉터리 루트급이면 거부
for guard in "$HOME" "$CLAUDE_DIR" "$CODEX_DIR" "$HOME/.config" "$HOME/.claude/skills" "$HOME/.codex/skills"; do
  if [ "$SRC_ABS" = "$guard" ]; then
    die "디렉터리 루트는 흡수할 수 없다: $SRC_ABS"
  fi
done

# 5. 시크릿으로 보이는 파일은 거부 (레포에 커밋될 위험)
BASE="$(basename "$SRC_ABS")"
case "$BASE" in
  .env|.env.*|*.pem|*.key|*_rsa|*_ed25519|.claude.json|auth.json|credentials*|*credentials*|*.credentials.json)
    die "시크릿으로 보이는 파일은 흡수하지 않는다: $BASE" ;;
esac
case "$SRC_ABS" in
  "$CODEX_DIR"/auth.json|"$HOME"/.ssh/*|"$HOME"/.aws/*|"$HOME"/.gnupg/*)
    die "인증 정보 경로는 흡수하지 않는다: $SRC_ABS" ;;
esac

# 6. destination 이 레포 안으로 정규화되는가 (.. 탈출 차단)
#    디렉터리를 미리 만들지 않는다. 검사 단계에서 부수효과를 내면 거부된 요청도 흔적을 남긴다.
case "$DEST_REL" in
  /*) die "레포 상대경로를 넣어야 한다(절대경로 불가): $DEST_REL" ;;
esac
DEST_ABS="$(python3 -c 'import os,sys; print(os.path.normpath(os.path.join(sys.argv[1], sys.argv[2])))' "$REPO" "$DEST_REL")"
case "$DEST_ABS/" in
  "$REPO/"*) ;;
  *) die "대상이 레포 밖으로 벗어난다: $DEST_ABS" ;;
esac
[ "$DEST_ABS" = "$REPO" ] && die "레포 루트 자체를 대상으로 할 수 없다"

# 7. .git 안으로는 못 넣는다
case "$DEST_ABS" in
  "$REPO"/.git|"$REPO"/.git/*) die ".git 안에는 넣을 수 없다: $DEST_ABS" ;;
esac

# 8. 대상이 이미 있으면 덮지 않는다
[ -e "$DEST_ABS" ] && die "대상이 이미 있다: $DEST_ABS"

# ── 실행 ──────────────────────────────────────────────────────────
log ""
log "  이동:  $SRC_ABS"
log "    ->   $DEST_ABS"
log "  링크:  $SRC_ABS -> $DEST_ABS"
log ""
confirm "진행할까?" || die "취소했다"

mkdir -p "$(dirname "$DEST_ABS")"
mv "$SRC_ABS" "$DEST_ABS"
ln -sfn "$DEST_ABS" "$SRC_ABS"
ok "흡수 완료. git status 로 확인하고 커밋할 것."
