# AI-SETUP

## 1. 개요

내 **Claude Code + Codex CLI** 설정 원본 저장소.

이 폴더 자체를 Claude 나 Codex 가 읽는 게 아니다. 여기는 **원본 보관소**이고,
`scripts/install.sh` 가 원본을 실제 사용 위치(`~/.claude`, `~/.codex`)에 연결하거나 병합한다.

```
AI-SETUP/instructions/CLAUDE.md
        ↓ 심볼릭 링크
~/.claude/CLAUDE.md
```

링크이므로 한쪽을 고치면 다른 쪽도 같이 바뀐다. 다른 기기에서는 `git pull` 만 하면 반영된다.
단, `settings.json` 과 `config.toml` 은 병합 방식이라 pull 후 `./scripts/install.sh` 를 다시 돌려야 한다.

---

## 2. 설치 방법

```bash
git clone https://github.com/dev0leee/oh-dev0leee-agents.git ~/AI-SETUP
cd ~/AI-SETUP
cp .env.example .env.local      # EXA_API_KEY, FILESYSTEM_DIR 채우기
./scripts/install.sh
```

무엇이 바뀔지 먼저 보려면:

```bash
./scripts/install.sh --dry-run
```

| 명령 | 하는 일 |
|---|---|
| `./scripts/install.sh` | 전체 설치 (Claude + Codex + 진단) |
| `./scripts/install.sh --claude-only` / `--codex-only` | 한쪽만 |
| `./scripts/doctor.sh` | 진단만. 아무것도 고치지 않는다 (문제가 있으면 종료 코드 1) |

로그인(Claude · Codex)과 OAuth 인증은 자동 복원되지 않는다 →
[수동 단계](docs/DETAILS.md#자동으로-복원되지-않는-것-수동)

---

## 3. 구조

```
instructions/     지침 원본 — CLAUDE.md, AGENTS.md (각각 그 자체로 완결)
claude/           Claude 전용 — settings.json, omc-config.json, plugins.txt, mcp.json, hud/
codex/            Codex 전용 — config.toml(안전 기본값), unrestricted.toml(위험 권한)
skills/           두 도구가 공유하는 내 스킬
templates/project/ 새 프로젝트에 복사할 시작 세트
scripts/          설치·진단 도구
tests/            config.toml 병합기 회귀 테스트
.githooks/        pre-commit — gitleaks 시크릿 검사
```

`claude/mcp.json` 은 두 도구가 함께 읽는 MCP 단일 원본이다.

---

## 4. 설정

### Claude 에 설치되는 것

| 대상 | 방식 | 내용 |
|---|---|---|
| `~/.claude/CLAUDE.md` | 링크 | 전역 지침 |
| `~/.claude/.omc-config.json` | 링크 | OMC 기본값 |
| `~/.claude/hud/omc-hud-min.mjs` | 링크 | statusline 스크립트 |
| `~/.claude/skills/<name>` | 링크 | `skills/` 의 내 스킬 |
| `~/.claude/settings.json` | 병합 | 전역 deny·ask 목록 + statusLine + tui — [소유권 기반 병합](docs/DETAILS.md#settingsjson-소유권) |
| 마켓플레이스 | CLI | `claude-plugins-official`, `omc`, `last30days-skill` |
| 플러그인 | CLI | `oh-my-claudecode@omc` (enabled), `last30days@last30days-skill` (disabled) |
| MCP | CLI | `context7`, `github`, `lazyweb`, `exa`, `filesystem` |

### Codex 에 설치되는 것

| 대상 | 방식 | 내용 |
|---|---|---|
| `~/.codex/AGENTS.md` | 링크 | 전역 지침 (금지 명령 규칙 포함) |
| `~/.codex/skills/<name>` | 링크 | `skills/` 의 내 스킬 (Claude 와 같은 원본) |
| `~/.codex/unrestricted.config.toml` | 링크 | `codex --profile unrestricted` 용 위험 권한 프로필 |
| `~/.codex/config.toml` | 병합 | `approval_policy` + `default_permissions` + 파일 glob deny (`hooks.state` / `projects` / `marketplaces` 는 보존) |
| MCP | CLI | `context7`, `exa` |

> Codex 에는 명령 단위 차단 기능이 없어서 위험 명령은 `AGENTS.md` 규칙으로만 막힌다.
> 파일 접근만 `[permissions.locked]` 로 실제 강제된다 →
> [권한 설정 상세](docs/DETAILS.md#권한-설정)

---

## 5. 추가 내용

설계 판단, Codex 실측 규칙, 보안·테스트 등 자세한 내용은 별도 문서에 있다.

**→ [docs/DETAILS.md](docs/DETAILS.md)**

- [지침이 두 파일로 나뉜 이유](docs/DETAILS.md#지침이-두-파일로-나뉜-이유)
- [링크하는 것 / 병합하는 것](docs/DETAILS.md#링크하는-것--병합하는-것)
- [자동으로 복원되지 않는 것 (수동)](docs/DETAILS.md#자동으로-복원되지-않는-것-수동)
- [스크립트 전체 목록 · 레포 경로 이동 · 스킬 추가](docs/DETAILS.md#스크립트)
- [MCP 멱등 등록 규칙](docs/DETAILS.md#mcp)
- [플러그인 목록 포맷](docs/DETAILS.md#플러그인)
- [권한 설정 · Codex 파일 경로 규칙 (0.144.6 실측)](docs/DETAILS.md#권한-설정)
- [Codex 위험 권한](docs/DETAILS.md#codex-위험-권한)
- [보안 · gitleaks pre-commit 훅](docs/DETAILS.md#보안)
- [알려진 한계](docs/DETAILS.md#알려진-한계)
- [테스트](docs/DETAILS.md#테스트)
- [검증 버전](docs/DETAILS.md#검증-버전)
