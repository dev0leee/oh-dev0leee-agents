#!/usr/bin/env bash
# git diff 를 읽기 좋게 만드는 delta 를 설치하고 전역 gitconfig 에 연결한다.
#   ./scripts/install-delta.sh [--yes] [--dry-run]
#
# ~/.gitconfig 를 직접 고치지 않는다. 설정 본체는 레포의 git/delta.gitconfig 에 두고
# include.path 한 줄만 추가한다. 그래야 pull 하면 바로 반영되고, 되돌리기도 한 줄이다.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

for arg in "$@"; do
  case "$arg" in
    --yes|-y)  ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) die "알 수 없는 옵션: $arg" ;;
  esac
done

CONF="$REPO/git/delta.gitconfig"
[ -f "$CONF" ] || die "설정 원본이 없다: $CONF"

step "[1/3] delta 바이너리"
if have delta; then
  skip "$(delta --version 2>/dev/null | head -1) (이미 설치됨)"
elif [ "$DRY_RUN" -eq 1 ]; then
  skip "(dry-run) brew install git-delta"
elif have brew && confirm "delta 가 없다. brew 로 설치할까? (brew install git-delta)"; then
  brew install git-delta
  ok "delta 설치"
else
  # 설정은 그대로 걸어둔다. 나중에 delta 를 깔면 바로 동작한다.
  warn "delta 미설치 — 설정만 연결한다. 지금 상태로 git diff 를 돌리면 pager 를 못 찾는 에러가 난다."
  warn "  설치: brew install git-delta   (그 외: https://github.com/dandavison/delta#installation)"
fi

step "[2/3] 기존 설정 확인"
# include 는 파일 끝에 붙으므로 우리 core.pager 가 기존 값을 덮는다. 조용히 덮지 않고 알린다.
# --global 은 --includes 없이는 include 를 따라가지 않는다. 여기서는 그게 맞다.
# 알고 싶은 건 "우리가 덮을 사용자 본인의 값"이지 우리가 방금 넣은 값이 아니다.
cur_pager="$(git config --global --get core.pager || true)"
if [ -z "$cur_pager" ]; then
  skip "~/.gitconfig 자체에 core.pager 없음 — 덮어쓸 값이 없다"
elif [ "$cur_pager" = "delta" ]; then
  skip "전역 core.pager 가 이미 delta"
else
  warn "전역 core.pager 가 이미 설정돼 있다: $cur_pager"
  warn "  include 는 뒤에 붙으므로 앞으로는 delta 가 우선한다. 되돌리려면 아래 해제 명령을 쓸 것."
fi

step "[3/3] gitconfig 연결"
if git config --global --get-all include.path 2>/dev/null | grep -qxF "$CONF"; then
  skip "include.path (이미 연결됨)"
elif [ "$DRY_RUN" -eq 1 ]; then
  skip "(dry-run) git config --global --add include.path $CONF"
else
  git config --global --add include.path "$CONF"
  ok "include.path -> git/delta.gitconfig"
fi

log ""
if [ "$DRY_RUN" -eq 1 ]; then
  skip "(dry-run) 아무것도 바꾸지 않았다"
else
  ok "delta 설치 완료 — 이제 그냥 git diff 를 치면 된다"
fi
log "   좌우 2단 보기:  git -c delta.side-by-side=true diff"
log "   설정 수정:      $CONF"
log "   해제:           git config --global --unset include.path '$CONF'"
