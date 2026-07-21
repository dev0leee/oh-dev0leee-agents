# AI-SETUP

내 **Claude Code + Codex CLI** 설정 원본 저장소.

이 폴더 자체를 Claude 나 Codex 가 읽는 게 아니다. 여기는 **원본 보관소**이고,
`scripts/install.sh` 가 원본을 실제 사용 위치(`~/.claude`, `~/.codex`)에 연결하거나 병합한다.

```
AI-SETUP/instructions/CLAUDE.md
        ↓ 심볼릭 링크
~/.claude/CLAUDE.md
```

링크이므로 한쪽을 고치면 다른 쪽도 같이 바뀐다. 다른 기기에서는 `git pull` 만 하면 반영된다.

---

## 구조

```
instructions/     지침 원본 — 두 파일 모두 그 자체로 완결돼 있다
  CLAUDE.md         → ~/.claude/CLAUDE.md
  AGENTS.md         → ~/.codex/AGENTS.md
claude/           Claude 전용 자료
  settings.json     내가 소유한 키만 (병합용)
  omc-config.json   OMC 기본값 (링크)
  plugins.txt       마켓플레이스 + 플러그인 (TSV)
  mcp.json          MCP 단일 원본 — Codex 설치도 이 파일을 읽는다
  hud/              statusline 스크립트 (링크)
codex/            Codex 전용 자료
  config.toml       안전한 기본값 (병합용)
  unrestricted.toml 위험 권한 — --unrestricted 로만 적용
skills/           두 도구가 공유하는 내 스킬 (링크)
templates/project/ 새 프로젝트에 복사할 시작 세트
scripts/          설치·진단 도구
tests/            config.toml 병합기 회귀 테스트
```

### 지침이 두 파일로 나뉜 이유

`common.md` 를 만들어 합성하지 않는다. 공통 규칙은 `CLAUDE.md` 와 `AGENTS.md` 에 **의도적으로 중복**한다.

공통 부분은 30~50줄인데 그걸 DRY 하게 만들려면 생성 디렉터리·빌드 스크립트·체크섬·stale 검사가 전부 따라온다.
중복 50줄을 없애려고 인프라 300줄을 들이는 건 이 규모에서 손해다. 대신 중간 생성물이 없어서
`cat ~/.claude/CLAUDE.md` 가 곧 `instructions/CLAUDE.md` 이고, 지침 수정은 `git pull` 만으로 끝난다.

> **공통 내용을 바꿀 때는 두 파일을 함께 수정할 것.**

---

## 링크하는 것 / 병합하는 것

### 링크 (사람만 수정하는 파일)

| 홈 | 레포 |
|---|---|
| `~/.claude/CLAUDE.md` | `instructions/CLAUDE.md` |
| `~/.codex/AGENTS.md` | `instructions/AGENTS.md` |
| `~/.claude/.omc-config.json` | `claude/omc-config.json` |
| `~/.claude/hud/omc-hud-min.mjs` | `claude/hud/omc-hud-min.mjs` |
| `~/.claude/skills/<name>` | `skills/<name>` |
| `~/.codex/skills/<name>` | `skills/<name>` (같은 원본) |
| `~/.codex/unrestricted.config.toml` | `codex/unrestricted.toml` |

→ **`git pull` 만으로 반영된다.**

### 병합 (사람 + 프로그램이 같이 쓰는 파일)

`~/.claude/settings.json` 과 `~/.codex/config.toml` **2개만** 링크하지 않는다.

| 파일 | 프로그램이 쓰는 것 |
|---|---|
| `~/.claude/settings.json` | `enabledPlugins`, `extraKnownMarketplaces` (`claude plugin` CLI) |
| `~/.codex/config.toml` | `hooks.state.*` 해시 21개, `marketplaces.*` 로컬 캐시 경로, `projects."/Users/..."` trust, `tui.*`, `agents.*`, `notify` |

링크를 걸면 코덱스를 실행할 때마다 레포가 더러워지고, 공개 저장소에 내 디렉터리 구조와
프로젝트 신뢰 목록이 커밋된다. 다른 기기에서 pull 하면 그 기기에 안 맞는 trust 상태가 덮인다.

대신 **내가 선언한 키만 덮어쓰고 나머지는 바이트 그대로 통과**시킨다
(`scripts/toml_upsert.py`, `jq '. * $mine'`).

→ 이쪽을 바꿨으면 pull 후 **`./scripts/install.sh` 를 다시 돌려야 한다.**

---

## 처음 설치

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

### 자동으로 복원되지 않는 것 (수동)

1. Claude 로그인 — `claude`
2. Codex 로그인 — `codex login`
3. GitHub MCP OAuth — `claude` 실행 후 `/mcp` 에서 github 로그인
4. Lazyweb MCP 인증 — 최초 사용 시 안내를 따를 것
5. API 키 — `.env.local` 에 입력 후 `./scripts/install.sh` 재실행
6. Codex 플러그인 `omo@sisyphuslabs` — 아래 "알려진 한계" 참고

---

## 스크립트

| 명령 | 하는 일 |
|---|---|
| `./scripts/install.sh` | 전체 설치 (Claude + Codex + 진단) |
| `./scripts/install.sh --claude-only` / `--codex-only` | 한쪽만 |
| `./scripts/install.sh --dry-run` | 아무것도 바꾸지 않고 계획만 출력 |
| `./scripts/install-codex.sh --unrestricted` | Codex 위험 권한을 전역 적용 (확인 프롬프트) |
| `./scripts/doctor.sh` | 진단만. 아무것도 고치지 않는다 |
| `./scripts/adopt.sh <홈경로> <레포경로>` | 기존 홈 파일을 레포로 흡수하고 링크로 교체 |
| `./scripts/init-project.sh <경로>` | 새 프로젝트에 `AGENTS.md` / `CLAUDE.md` 배치 |

`--yes` 는 **"질문 없이 진행"** 의 의미로만 쓴다. 위험 설정을 켜는 건 `--unrestricted` 뿐이다.

### 스킬 추가하기

```bash
./scripts/adopt.sh ~/.claude/skills/my-skill skills/my-skill
./scripts/install.sh            # Codex 쪽에도 링크
```

`adopt.sh` 는 홈 밖 경로, 디렉터리 루트, 시크릿으로 보이는 파일(`.env*`, `auth.json`, `*.pem`, `.claude.json` 등),
레포 밖으로 벗어나는 대상, `.git` 내부를 모두 거부한다.

---

## MCP

`claude/mcp.json` 이 단일 원본이고, `targets` 로 어느 도구에 등록할지 정한다.
`env` 에는 **환경변수 이름만** 적는다. 실제 값은 `.env.local` 에서 읽는다.

등록은 멱등하다:

```
현재에 없음         → add
현재와 선언이 다름  → remove 후 add
같음                → 아무것도 안 함     ← OAuth 세션이 보존된다
```

`add || true` 를 쓰지 않는 이유는 선언을 바꿔도 기존 등록이 갱신되지 않기 때문이고,
무조건 remove+add 하지 않는 이유는 HTTP 서버의 OAuth 인증이 매번 풀리기 때문이다.
HTTP 서버를 교체할 때는 재인증이 필요할 수 있다고 알리고 확인을 받는다.

비교는 stdio 는 `type/command/args/env 키 집합`, http 는 `type/url` 만 본다.
API 키 값·OAuth 토큰·세션은 비교에도 로그에도 넣지 않는다.

---

## 플러그인

`claude/plugins.txt` 는 **탭 구분** TSV 다 (공백 구분은 URL 때문에 깨진다).

```
marketplace<TAB><이름><TAB><소스>
plugin<TAB><plugin@marketplace><TAB>enabled|disabled
```

**목록에 없는 플러그인은 건드리지 않는다.** 로컬에서만 쓰는 플러그인은 그대로 남는다.
마찬가지로 `~/.claude/skills/` 를 통째로 동기화하지 않으므로, 외부에서 받은 스킬(`impeccable` 등)은 보존된다.

| 종류 | 관리 주체 |
|---|---|
| 내가 작성한 스킬 | 레포 (링크) |
| 플러그인·외부 제작 스킬 | 해당 설치 수단. 레포는 건드리지 않음 |

---

## 권한 설정

두 도구의 권한 모델이 달라서 **1:1 대응이 되지 않는다.** 아래가 실제 매핑이다.

| Claude (`permissions`) | Codex 대응 | 상태 |
|---|---|---|
| `deny: Read(**/.env*)` 등 파일 glob | `[permissions.dev.filesystem]` 의 `"deny"` | ✅ 직접 대응 |
| `deny: Write(.github/workflows/*)` | `".github/workflows/**" = "read"` (읽기만) | ✅ 직접 대응 |
| `deny: Bash(sudo *)`, `Bash(rm -rf *)` | `sandbox_mode = "workspace-write"` — 워크스페이스 밖 쓰기 차단 + 에스컬레이션 시 승인 | ⚠️ 개념이 다름 |
| `deny: Bash(curl * \| sh)`, `Bash(wget *)` | 샌드박스의 `restricted network` | ⚠️ 간접 |
| `deny: Bash(git push *)`, `Bash(npm publish *)` | — | ❌ **직접 대응 없음** |
| `allow: [...]` 화이트리스트 | — | ❌ 대응 없음 (Codex 는 승인 정책으로 처리) |

Codex 에도 명령 단위 규칙(`~/.codex/rules/*.rules` 의 `prefix_rule`)이 있어 보이지만,
설정 로드 시점에 검증되지 않아 `decision` 에 어떤 값이 유효한지 확인하지 못했다.
검증 못 한 DSL 로 보안 규칙을 만들지 않았다. 필요해지면 그때 확인해서 추가할 것.

### 어디에 무엇이 들어있나

| 위치 | 내용 |
|---|---|
| `claude/settings.json` (전역) | **deny 목록만.** 모든 프로젝트에 걸리는 안전망 |
| `templates/project/.claude/settings.json` | allow + deny + `defaultMode: acceptEdits` 전체 |
| `codex/config.toml` | `default_permissions = "dev"` + `[permissions.dev.filesystem]` |

전역에 allow 목록을 넣지 않은 이유: `Write(src/**)`, `Bash(npm run *)` 은 프로젝트 구조를
전제하므로 모든 프로젝트에 적용하면 의미가 없다. `defaultMode: acceptEdits` 도 프로젝트 단위로만 켠다.

### Codex 파일 경로 규칙 (0.144.6 실측)

설정이 거부되는 조건을 직접 확인했다:

- 경로는 **절대경로이거나 `~/` 또는 `:` 로 시작**해야 한다
  → `**/.env*` 를 최상위에 두면 `must be absolute, use ~/..., or start with :` 로 실패
- 워크스페이스 상대 glob 은 `[permissions.<name>.filesystem.":workspace_roots"]` 아래에 둔다
- **glob 에는 `"deny"` 만** 줄 수 있다. `"read"` 를 주려면 정확한 경로이거나 `/**` 로 끝나야 한다
  → `".github/workflows/*" = "read"` 는 실패, `"/**"` 로 고쳐야 통과
- `default_permissions` 는 **루트 스칼라**라 첫 `[테이블]` 헤더보다 위에 있어야 한다.
  `[features]` 뒤에 두면 `features.default_permissions` 가 되어 `expected a boolean` 으로 실패한다
  (문법은 멀쩡해서 `tomllib` 파싱만으로는 안 잡힌다 — `install-codex.sh` 가 설치 전에
  격리된 `CODEX_HOME` 으로 코덱스에 직접 물어보고, 거부되면 원본을 건드리지 않는다)

---

## ⚠️ Codex 권한 설정

`codex/config.toml` 의 기본값은 **안전한 쪽**이다.

```toml
approval_policy = "on-request"
sandbox_mode    = "workspace-write"
```

`approval_policy = "never"` + `sandbox_mode = "danger-full-access"` 는 **코덱스가 승인 없이
전체 디스크에 임의 명령을 실행**할 수 있다는 뜻이다. 신뢰하지 않는 저장소를 여는 순간 무단 실행이 가능하다.
설치할 때 한 번 확인받는 것으로는 부족하다 — 이후 실행할 때마다 계속 그 상태이고 몇 주 뒤엔 잊는다.

그래서 이 조합은 `codex/unrestricted.toml` 로 분리했고 두 가지 방법으로만 쓴다.

```bash
codex --profile unrestricted            # 그때만 (권장)
./scripts/install-codex.sh --unrestricted   # 전역 적용 (확인 프롬프트)
```

전역으로 켰다가 되돌리려면 `./scripts/install-codex.sh` 를 그냥 다시 돌리면 된다.

---

## 🔐 보안

- **`~/.claude.json` 은 절대 커밋하지 않는다.** MCP 의 OAuth 베어러 토큰과 API 키가 평문으로 들어있다. `.gitignore` 로 막아뒀다.
- **`codex mcp add --env` 는 API 키를 `~/.codex/config.toml` 에 평문으로 쓴다.** 이 파일도 절대 레포에 넣지 않는다.
- `scripts/extract_sections.py` 는 진단용 diff 도구라 `*_KEY`, `*_TOKEN`, `env` 테이블 값을 자동으로 `***` 로 가린다.
- 실제 키는 `.env.local` 에만 둔다. 커밋 전 `git diff` 로 확인할 것.

---

## 알려진 한계

- **GitHub MCP 는 Codex 에 등록되지 않는다.** codex-cli 0.144.6 에서
  `Dynamic client registration not supported` 로 실패한다. `mcp.json` 에서 `targets` 를 `["claude"]` 로 뒀다.
- **`omo@sisyphuslabs` 는 자동 복원되지 않는다.** Codex 마켓플레이스가 전부 로컬 경로이고
  이 마켓플레이스는 git 저장소가 아니라 원본 URL 이 기록돼 있지 않다. 새 기기에서는 직접 설치해야 한다.
  `install-codex.sh` 는 미설치를 감지해 경고만 낸다.
- **`codex mcp add` 는 `config.toml` 전체를 자기 포맷으로 다시 쓴다.** 섹션 순서가 바뀌고
  `120` 이 `120.0` 이 되는 식이다. 값은 보존되므로 문제는 없지만 diff 가 커 보일 수 있다.
- `network_access` 는 Codex 의 유효한 최상위 키가 아니다(공식 레퍼런스에 없음). 기존 파일에 있어도
  건드리지 않고 그대로 둔다. 네트워크는 `features.network_proxy` 나 `[sandbox_workspace_write]` 소관이다.

---

## 테스트

`config.toml` 병합기는 런타임 상태를 날려먹으면 안 되므로 회귀 테스트가 있다.

```bash
python3 -m unittest discover -s tests -v
```

빈 파일 / 기존 키 중복 없이 교체 / `[features]` 자동 생성 / 주석·공백 보존 /
여러 줄 배열·삼중따옴표 / 실제 `config.toml` 사본 — 6개 fixture 각각에 대해
결과를 `tomllib` 으로 재파싱하고, 보존 대상 블록의 문자열 diff 가 비어 있는지,
2회 적용이 1회와 바이트 동일한지(멱등) 확인한다.

---

## 검증 버전

macOS · Claude Code · `codex-cli 0.144.6` · `jq 1.7.1` · `python3 3.14`

Codex 의 CLI 플래그와 프로필 파일 규약은 버전에 따라 바뀔 수 있다.
스크립트는 `--help` 로 지원 여부를 먼저 확인하고 없으면 우회한다.
