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
if ! have jq; then
  warn "jq 가 없어 settings.json 병합을 건너뛴다 (brew install jq)"
else
  target="$CLAUDE_DIR/settings.json"
  current='{}'
  [ -s "$target" ] && current="$(cat "$target")"
  merged="$(printf '%s' "$current" | jq --argjson mine "$(cat "$REPO/claude/settings.json")" '. * $mine')"
  if [ "$(printf '%s' "$current" | jq -S .)" = "$(printf '%s' "$merged" | jq -S .)" ]; then
    skip "settings.json (변경 없음)"
  elif [ "$DRY_RUN" -eq 1 ]; then
    log "$(printf '%s' "$merged" | jq -S . | diff <(printf '%s' "$current" | jq -S .) - || true)"
    skip "(dry-run) settings.json 을 위와 같이 병합"
  else
    backup "$target"
    mkdir -p "$CLAUDE_DIR"
    printf '%s\n' "$merged" > "$target.tmp" && mv "$target.tmp" "$target"
    ok "settings.json 병합 (enabledPlugins 등 기존 키는 보존)"
  fi
fi

step "[3/4] 마켓플레이스 + 플러그인"
# 목록에 없는 플러그인은 건드리지 않는다. 로컬에서만 쓰는 플러그인은 그대로 남는다.
if ! have claude; then
  warn "claude CLI 가 없어 플러그인 단계를 건너뛴다"
else
  installed_markets="$(claude plugin marketplace list 2>/dev/null || true)"
  installed_plugins="$(claude plugin list 2>/dev/null || true)"

  while IFS=$'\t' read -r kind name value; do
    case "$kind" in
      ''|'#'*) continue ;;
    esac
    [ -n "${name:-}" ] || continue

    if [ "$kind" = "marketplace" ]; then
      if grep -qF "❯ $name" <<<"$installed_markets"; then
        skip "marketplace $name (이미 등록됨)"
      elif [ "$DRY_RUN" -eq 1 ]; then
        skip "(dry-run) claude plugin marketplace add $value"
      elif claude plugin marketplace add "$value" >/dev/null 2>&1; then
        ok "marketplace $name 등록"
      else
        err "marketplace $name 등록 실패: $value"
      fi

    elif [ "$kind" = "plugin" ]; then
      if grep -qF "❯ $name" <<<"$installed_plugins"; then
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
      cur_state="$(awk -v p="❯ $name" '
        index($0, p) {found=1; next}
        found && /Status:/ {print; exit}
      ' <<<"$installed_plugins")"
      if [ "$want" = "disabled" ] && ! grep -q 'disabled' <<<"$cur_state"; then
        [ "$DRY_RUN" -eq 1 ] && skip "(dry-run) claude plugin disable $name" \
          || { claude plugin disable "$name" -s user >/dev/null 2>&1 && ok "plugin $name 비활성화"; }
      elif [ "$want" = "enabled" ] && grep -q 'disabled' <<<"$cur_state"; then
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
