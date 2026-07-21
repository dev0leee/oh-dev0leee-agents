#!/usr/bin/env bash
# Codex CLI 설정을 이 레포에서 홈으로 설치한다.
#   ./scripts/install-codex.sh [--unrestricted] [--yes] [--dry-run]
#
#   --unrestricted  위험 권한(승인 없음 + 전체 디스크 접근)을 전역 config.toml 에 적용한다.
#   --yes           확인 프롬프트를 자동 승인한다. 위험 권한을 켜는 의미가 아니다.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN=0
UNRESTRICTED=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)       ASSUME_YES=1 ;;
    --dry-run)      DRY_RUN=1 ;;
    --unrestricted) UNRESTRICTED=1 ;;
    *) die "알 수 없는 옵션: $arg" ;;
  esac
done

step "[1/4] 심볼릭 링크"
link_file instructions/AGENTS.md "$CODEX_DIR/AGENTS.md" "~/.codex/AGENTS.md"

for dir in "$REPO"/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  link_file "skills/$name" "$CODEX_DIR/skills/$name" "~/.codex/skills/$name"
done

# 프로필을 지원하면 위험 설정을 별도 프로필 파일로도 깔아둔다.
# 이러면 전역 설정을 위험하게 두지 않고 codex --profile unrestricted 로 그때만 쓸 수 있다.
if have codex && codex --help 2>/dev/null | grep -q -- '--profile'; then
  link_file codex/unrestricted.toml "$CODEX_DIR/unrestricted.config.toml" "~/.codex/unrestricted.config.toml"
  PROFILE_OK=1
else
  warn "이 codex 버전은 --profile 을 지원하지 않는다. 프로필 파일 설치를 건너뛴다."
  PROFILE_OK=0
fi

step "[2/4] config.toml 병합"
# 링크하지 않고 병합하는 이유: 코덱스가 hooks.state / marketplaces / projects /
# tui / agents 를 이 파일에 계속 써 넣는다. 통째로 덮으면 신뢰 상태가 날아간다.
overlays=(--overlay "$REPO/codex/config.toml")

if [ "$UNRESTRICTED" -eq 1 ]; then
  log ""
  warn "⚠️  --unrestricted: approval_policy=never + sandbox_mode=danger-full-access 를 전역 적용한다."
  warn "    코덱스가 승인 없이 전체 디스크에 임의 명령을 실행할 수 있게 된다."
  warn "    신뢰하지 않는 저장소를 여는 순간 무단 실행이 가능하다."
  if [ "$PROFILE_OK" -eq 1 ]; then
    warn "    전역으로 켜는 대신 'codex --profile unrestricted' 로 그때만 쓰는 방법도 있다."
  fi
  if confirm "전역 설정에 위험 권한을 적용할까?"; then
    overlays+=(--overlay "$REPO/codex/unrestricted.toml")
  else
    log "  건너뜀. 안전한 기본값으로 설치한다."
  fi
fi

target="$CODEX_DIR/config.toml"
current=""
[ -f "$target" ] && current="$(cat "$target")"
merged="$(printf '%s' "$current" | python3 "$REPO/scripts/toml_upsert.py" "${overlays[@]}")"

if [ "$merged" = "$current" ]; then
  skip "config.toml (변경 없음)"
elif [ "$DRY_RUN" -eq 1 ]; then
  diff <(printf '%s\n' "$current") <(printf '%s\n' "$merged") || true
  skip "(dry-run) config.toml 을 위와 같이 병합"
else
  backup "$target"
  mkdir -p "$CODEX_DIR"
  printf '%s\n' "$merged" > "$target.tmp"

  # 1) 문법 검사
  if ! python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' "$target.tmp"; then
    rm -f "$target.tmp"
    die "병합 결과가 올바른 TOML 이 아니다. 원본을 그대로 두었다."
  fi

  # 2) 의미 검사 — 코덱스가 실제로 받아들이는지 격리된 CODEX_HOME 으로 확인한다.
  #    문법은 멀쩡한데 코덱스가 거부하는 경우가 있다.
  #    (예: [features] 뒤에 놓인 루트 스칼라는 features.<key> 가 되어 타입 오류가 난다)
  if have codex; then
    probe="$(mktemp -d)"
    cp "$target.tmp" "$probe/config.toml"
    if ! probe_err="$(CODEX_HOME="$probe" codex mcp list 2>&1 >/dev/null)"; then
      rm -rf "$probe"; rm -f "$target.tmp"
      err "코덱스가 병합 결과를 거부했다. 원본을 그대로 두었다:"
      printf '%s\n' "$probe_err" | sed 's/^/      /' >&2
      exit 1
    fi
    rm -rf "$probe"
  fi

  mv "$target.tmp" "$target"
  ok "config.toml 병합 (hooks.state / projects / marketplaces 는 보존)"
fi

step "[3/4] 플러그인"
# Codex 마켓플레이스는 전부 로컬 경로라 sisyphuslabs 캐시만 봐서는 원본을 알 수 없다.
# 원본은 npm 의 lazycodex-ai (github.com/code-yeongyu/lazycodex) 이고, 그 설치기가
# 플러그인을 omo 라는 이름으로 sisyphuslabs 마켓플레이스에 등록한다. 이름이 달라서
# 캐시만 보면 연결이 안 보인다.
OMO_INSTALL=(npx --yes lazycodex-ai install)

# `codex plugin list` 는 미설치 플러그인도 같이 찍는다. 이름만 grep 하면
# "not installed" 줄까지 설치된 것으로 읽는다. 상태 칸을 같이 본다.
omo_installed() {
  codex plugin list 2>/dev/null |
    awk '$1 == "omo@sisyphuslabs" && $0 !~ /not installed/ { found = 1 } END { exit !found }'
}

if ! have codex; then
  warn "codex CLI 가 없어 플러그인 확인을 건너뛴다"
elif omo_installed; then
  skip "omo@sisyphuslabs (이미 설치됨)"
elif ! have npx; then
  warn "omo@sisyphuslabs 미설치 — npx 가 없다. 수동으로: ${OMO_INSTALL[*]}"
elif [ "$DRY_RUN" -eq 1 ]; then
  skip "(dry-run) omo@sisyphuslabs 설치: ${OMO_INSTALL[*]}"
elif confirm "omo@sisyphuslabs (lazycodex) 를 설치할까? — ${OMO_INSTALL[*]}"; then
  if "${OMO_INSTALL[@]}"; then
    if omo_installed; then
      ok "omo@sisyphuslabs 설치"
    else
      warn "설치기는 끝났는데 플러그인이 목록에 없다 — codex plugin list 로 확인할 것"
    fi
  else
    warn "omo@sisyphuslabs 설치 실패 — 수동으로: ${OMO_INSTALL[*]}"
  fi
else
  warn "omo@sisyphuslabs 미설치 — 나중에: ${OMO_INSTALL[*]}"
fi

step "[4/4] MCP 서버"
load_env
mcp_args=(--tool codex)
[ "$ASSUME_YES" -eq 1 ] && mcp_args+=(--yes)
[ "$DRY_RUN" -eq 1 ]    && mcp_args+=(--dry-run)
python3 "$REPO/scripts/mcp_reconcile.py" "${mcp_args[@]}"

log ""
ok "Codex 설치 완료"
if [ "$UNRESTRICTED" -eq 0 ] && [ "$PROFILE_OK" -eq 1 ]; then
  log "   위험 권한이 필요하면: codex --profile unrestricted"
fi
