#!/usr/bin/env bash
# Claude Code 설정을 이 레포에서 홈으로 설치한다.
#   ./scripts/install-claude.sh [--yes] [--dry-run]
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --yes|-y)  ASSUME_YES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) die "알 수 없는 옵션: $arg" ;;
  esac
done

step "[1/4] 심볼릭 링크"
link_file instructions/CLAUDE.md      "$CLAUDE_DIR/CLAUDE.md"          "~/.claude/CLAUDE.md"
link_file claude/omc-config.json      "$CLAUDE_DIR/.omc-config.json"   "~/.claude/.omc-config.json"
link_file claude/hud/omc-hud-min.mjs  "$CLAUDE_DIR/hud/omc-hud-min.mjs" "~/.claude/hud/omc-hud-min.mjs"

for dir in "$REPO"/skills/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  link_file "skills/$name" "$CLAUDE_DIR/skills/$name" "~/.claude/skills/$name"
done

step "[2/4] settings.json 병합"
# 링크하지 않고 병합하는 이유: claude plugin CLI 가 enabledPlugins /
# extraKnownMarketplaces 를 이 파일에 써 넣는다. 통째로 덮으면 그게 날아간다.
#
# 병합 규칙은 "소유권" 으로 정한다. jq 의 `*` 는 객체를 재귀 병합해서 어느 깊이까지
# 사용자 값이 살아남는지가 암묵적이 된다. 아래 두 목록으로 그걸 코드에 드러낸다.
#
#   OWNED   레포가 통째로 소유. 사용자가 손대도 설치할 때 레포 값으로 되돌아간다.
#   SHALLOW 최상위 키 단위로만 합친다. 사용자가 추가한 항목은 남고
#           레포에 있는 항목만 덮어쓴다.
#
# claude/settings.json 에 새 키를 넣으면서 목록에 추가하지 않으면 아래에서 막는다.
SETTINGS_OWNED='["permissions","statusLine","tui"]'
SETTINGS_SHALLOW='["env"]'

if ! have jq; then
  warn "jq 가 없어 settings.json 병합을 건너뛴다 (brew install jq)"
else
  unowned="$(jq -r --argjson owned "$SETTINGS_OWNED" --argjson shallow "$SETTINGS_SHALLOW" \
    'keys - $owned - $shallow | join(", ")' "$REPO/claude/settings.json")"
  [ -z "$unowned" ] || die "claude/settings.json 에 소유권이 정해지지 않은 키가 있다: $unowned
  → scripts/install-claude.sh 의 SETTINGS_OWNED 또는 SETTINGS_SHALLOW 에 추가할 것"

  target="$CLAUDE_DIR/settings.json"
  current='{}'
  [ -s "$target" ] && current="$(cat "$target")"
  merged="$(printf '%s' "$current" | jq \
    --argjson mine "$(cat "$REPO/claude/settings.json")" \
    --argjson owned "$SETTINGS_OWNED" \
    --argjson shallow "$SETTINGS_SHALLOW" '
      reduce $owned[]   as $k (.; if $mine|has($k) then .[$k] = $mine[$k] else . end)
    | reduce $shallow[] as $k (.; if $mine|has($k) then .[$k] = ((.[$k] // {}) + $mine[$k]) else . end)
  ')"

  # 통째로 교체되는 키는 사용자가 직접 넣은 내용(예: permissions.allow)을 잃는다.
  # 백업이 남지만 조용히 사라지면 곤란하므로 무엇이 덮이는지 이름을 밝힌다.
  clobbered="$(printf '%s' "$current" | jq -r --argjson mine "$(cat "$REPO/claude/settings.json")" \
    --argjson owned "$SETTINGS_OWNED" \
    '[$owned[] as $k | select(has($k) and (.[$k] != $mine[$k])) | $k] | join(", ")')"
  [ -z "$clobbered" ] || warn "레포가 소유한 키라 기존 값을 통째로 교체한다: $clobbered"

  if [ "$(printf '%s' "$current" | jq -S .)" = "$(printf '%s' "$merged" | jq -S .)" ]; then
    skip "settings.json (변경 없음)"
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "$(printf '%s' "$merged" | jq -S . | diff <(printf '%s' "$current" | jq -S .) - || true)"
    skip "(dry-run) settings.json 을 위와 같이 병합"
  else
    backup "$target"
    mkdir -p "$CLAUDE_DIR"
    printf '%s\n' "$merged" > "$target.tmp" && mv "$target.tmp" "$target"
    ok "settings.json 병합 (레포가 소유하지 않는 키는 그대로 둔다)"
  fi
fi

step "[3/4] 마켓플레이스 + 플러그인"
# 목록에 없는 플러그인은 건드리지 않는다. 로컬에서만 쓰는 플러그인은 그대로 남는다.
if ! have claude; then
  warn "claude CLI 가 없어 플러그인 단계를 건너뛴다"
else
  # 상태 판정은 JSON 을 우선한다. 사람용 출력("❯" 아이콘, "Status:" 문구)은
  # CLI 가 표시를 바꾸면 조용히 오탐이 나므로 JSON 이 없을 때만 폴백으로 쓴다.
  USE_JSON=0
  if have jq && supports_flag claude plugin list --json; then
    markets_json="$(claude plugin marketplace list --json 2>/dev/null || true)"
    plugins_json="$(claude plugin list --json 2>/dev/null || true)"
    if jq -e 'type == "array"' >/dev/null 2>&1 <<<"${markets_json:-}" \
    && jq -e 'type == "array"' >/dev/null 2>&1 <<<"${plugins_json:-}"; then
      USE_JSON=1
    fi
  fi
  if [ "$USE_JSON" -eq 0 ]; then
    warn "claude plugin --json 을 쓸 수 없어 화면 출력 파싱으로 대체한다 (CLI 출력이 바뀌면 오탐 가능)"
    installed_markets="$(claude plugin marketplace list 2>/dev/null || true)"
    installed_plugins="$(claude plugin list 2>/dev/null || true)"
  fi

  market_installed() {
    if [ "$USE_JSON" -eq 1 ]; then
      jq -e --arg n "$1" 'any(.[]; .name == $n)' >/dev/null 2>&1 <<<"$markets_json"
    else
      grep -qF "❯ $1" <<<"$installed_markets"
    fi
  }
  plugin_installed() {
    if [ "$USE_JSON" -eq 1 ]; then
      jq -e --arg n "$1" 'any(.[]; .id == $n)' >/dev/null 2>&1 <<<"$plugins_json"
    else
      grep -qF "❯ $1" <<<"$installed_plugins"
    fi
  }
  # 설치돼 있으면서 비활성 상태일 때만 성공. 미설치는 실패로 본다
  # (갓 설치한 플러그인은 목록 스냅샷에 없고, 기본값이 enabled 라 그게 맞다).
  plugin_disabled() {
    if [ "$USE_JSON" -eq 1 ]; then
      jq -e --arg n "$1" 'any(.[]; .id == $n and .enabled == false)' >/dev/null 2>&1 <<<"$plugins_json"
    else
      awk -v p="❯ $1" '
        index($0, p) {found=1; next}
        found && /Status:/ {print; exit}
      ' <<<"$installed_plugins" | grep -q 'disabled'
    fi
  }

  while IFS=$'\t' read -r kind name value; do
    case "$kind" in
      ''|'#'*) continue ;;
    esac
    [ -n "${name:-}" ] || continue

    if [ "$kind" = "marketplace" ]; then
      if market_installed "$name"; then
        skip "marketplace $name (이미 등록됨)"
      elif [ "$DRY_RUN" -eq 1 ]; then
        skip "(dry-run) claude plugin marketplace add $value"
      elif claude plugin marketplace add "$value" >/dev/null 2>&1; then
        ok "marketplace $name 등록"
      else
        err "marketplace $name 등록 실패: $value"
      fi

    elif [ "$kind" = "plugin" ]; then
      if plugin_installed "$name"; then
        skip "plugin $name (이미 설치됨)"
      elif [ "$DRY_RUN" -eq 1 ]; then
        skip "(dry-run) claude plugin install $name -s user"
      elif claude plugin install "$name" -s user >/dev/null 2>&1; then
        ok "plugin $name 설치"
      else
        err "plugin $name 설치 실패"
        continue
      fi

      # enabled/disabled 상태 맞추기
      want="${value:-enabled}"
      if [ "$want" = "disabled" ] && ! plugin_disabled "$name"; then
        [ "$DRY_RUN" -eq 1 ] && skip "(dry-run) claude plugin disable $name" \
          || { claude plugin disable "$name" -s user >/dev/null 2>&1 && ok "plugin $name 비활성화"; }
      elif [ "$want" = "enabled" ] && plugin_disabled "$name"; then
        [ "$DRY_RUN" -eq 1 ] && skip "(dry-run) claude plugin enable $name" \
          || { claude plugin enable "$name" -s user >/dev/null 2>&1 && ok "plugin $name 활성화"; }
      fi
    fi
  done < "$REPO/claude/plugins.txt"
fi

step "[4/4] MCP 서버"
load_env
mcp_args=(--tool claude)
[ "$ASSUME_YES" -eq 1 ] && mcp_args+=(--yes)
[ "$DRY_RUN" -eq 1 ]    && mcp_args+=(--dry-run)
python3 "$REPO/scripts/mcp_reconcile.py" "${mcp_args[@]}"

log ""
ok "Claude 설치 완료"
