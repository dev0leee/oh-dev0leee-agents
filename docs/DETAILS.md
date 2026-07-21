# 추가 내용

[← README 로 돌아가기](../README.md)

이 문서는 설계 판단과 실측 정보를 모아둔 곳이다. 설치만 할 거라면 README 로 충분하다.

---

## 지침이 두 파일로 나뉜 이유

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
(`scripts/toml_upsert.py`, `scripts/install-claude.sh`).

→ 이쪽을 바꿨으면 pull 후 **`./scripts/install.sh` 를 다시 돌려야 한다.**

### settings.json 소유권

`~/.claude/settings.json` 은 최상위 키마다 **누가 소유하는지**를 정해두고 병합한다.
목록은 `scripts/install-claude.sh` 의 `SETTINGS_OWNED` / `SETTINGS_SHALLOW` 에 있다.

| 키 | 소유 | 동작 |
|---|---|---|
| `permissions` | 레포 | **통째로 교체.** 손으로 넣은 `permissions.allow` 도 사라진다 |
| `statusLine` | 레포 | 통째로 교체 |
| `tui` | 레포 | 통째로 교체 |
| `env` | 공유 | 최상위 키 단위로만 합친다. 내가 추가한 환경변수는 남는다 |
| 그 외 전부 | 사용자·CLI | 건드리지 않는다 (`enabledPlugins`, `extraKnownMarketplaces`, `hooks`, `model` …) |

deny 목록이 단일 원본이어야 해서 `permissions` 는 재귀 병합하지 않는다. 재귀 병합을 하면
예전에 넣어둔 `allow` 규칙이 새 deny 규칙보다 오래 살아남아 조용히 구멍이 된다.
교체로 값을 잃는 키가 있으면 설치할 때 이름을 찍어주고, 덮어쓰기 전 `.bak` 을 남긴다.

`claude/settings.json` 에 새 최상위 키를 추가하면서 두 목록 어디에도 넣지 않으면
설치가 그 자리에서 멈춘다. 소유권을 정하지 않은 키가 조용히 무시되지 않게 하기 위한 것이다.

---

## 자동으로 복원되지 않는 것 (수동)

1. Claude 로그인 — `claude`
2. Codex 로그인 — `codex login`
3. Lazyweb MCP 인증 — 최초 사용 시 안내를 따를 것
4. API 키 — `.env.local` 에 입력 후 `./scripts/install.sh` 재실행
5. Codex 플러그인 `omo@sisyphuslabs` — 아래 "알려진 한계" 참고

---

## 스크립트

| 명령 | 하는 일 |
|---|---|
| `./scripts/install.sh` | 전체 설치 (Claude + Codex + 진단) |
| `./scripts/install.sh --claude-only` / `--codex-only` | 한쪽만 |
| `./scripts/install.sh --dry-run` | 아무것도 바꾸지 않고 계획만 출력 |
| `./scripts/install-codex.sh --unrestricted` | Codex 위험 권한을 전역 적용 (확인 프롬프트) |
| `./scripts/install-gitleaks.sh [--global]` | gitleaks pre-commit 훅 설치 (`--global` 은 모든 레포에 적용) |
| `./scripts/doctor.sh` | 진단만. 아무것도 고치지 않는다 |
| `./scripts/adopt.sh <홈경로> <레포경로>` | 기존 홈 파일을 레포로 흡수하고 링크로 교체 |
| `./scripts/init-project.sh <경로>` | 새 프로젝트에 `AGENTS.md` / `CLAUDE.md` 배치 |

`--yes` 는 **"질문 없이 진행"** 의 의미로만 쓴다. 위험 설정을 켜는 건 `--unrestricted` 뿐이다.

### 레포를 다른 경로로 옮겼다면

심볼릭 링크는 절대경로를 가리키므로 **레포를 옮기면 7개가 전부 끊어진다.**
`~/.claude/CLAUDE.md` 가 죽으면 전역 지침이 통째로 사라지는데 조용히 사라져서 알아채기 어렵다.

```bash
cd <새 경로>
./scripts/install.sh      # 끊어진 링크를 새 경로로 다시 건다
```

`doctor.sh` 도 링크가 끊어졌거나 엉뚱한 곳을 가리키면 잡아낸다.

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
| `deny: Read(**/.env*)` 등 파일 glob | `[permissions.locked.filesystem]` 의 `"deny"` | ✅ 강제됨 |
| `deny: Write(.github/workflows/*)` | `".github/workflows/**" = "deny"` | ✅ 강제됨 |
| `deny: Bash(rm -rf *)`, `sudo`, `git push`, `npm publish`, `chmod -R`, `curl \| sh`, `wget \| sh`, `find . -delete`, `shred` | `instructions/AGENTS.md` 의 **"금지 명령"** 규칙 | ⚠️ **지침일 뿐 강제 아님** |
| `allow: [...]` 화이트리스트 | `approval_policy = "untrusted"` (신뢰된 명령 외 승인) | ⚠️ 개념이 다름 |

**중요한 비대칭**: Claude 는 `permissions.deny` 가 하드 차단이지만, Codex 에는 명령 단위 차단이 없다.
그래서 위험 명령은 `AGENTS.md` 규칙으로만 막힌다 — 모델이 규칙을 어기면 막을 방법이 없다.
파일 접근만 `[permissions.locked]` 로 실제 강제된다.

`~/.codex/rules/*.rules` 의 `prefix_rule` 로 명령을 막을 수 있어 보였지만, `decision` 에
`deny`/`reject`/`forbid`/`ask` 를 전부 넣어도 모두 통과했다. 설정 로드 시점에 검증되지 않는다는
뜻이라 어떤 값이 실제로 동작하는지 확인하지 못했다. 검증 못 한 DSL 로 보안 규칙을 만들면
"막고 있다"는 착각만 준다.

### 어디에 무엇이 들어있나

| 위치 | 내용 |
|---|---|
| `claude/settings.json` (전역) | **deny + ask 목록.** 모든 프로젝트에 걸리는 안전망 (allow 없음) |
| `templates/project/.claude/settings.json` | allow + deny + `defaultMode: acceptEdits` 전체 |
| `codex/config.toml` | `approval_policy = "untrusted"` + `default_permissions = "locked"` + 파일 glob deny |
| `instructions/AGENTS.md` | Codex 용 금지 명령 목록 (Codex 에 대응 기능이 없어서) |

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
- **경로 하나당 접근수준 하나다.** Claude 처럼 Read deny 목록과 Write deny 목록을 따로 쓰면
  같은 키가 두 번 나와 `duplicate key` 로 파싱이 실패한다. `"deny"` 하나가 읽기·쓰기를 모두 막는다
- `glob_scan_max_depth` 는 `[permissions.<name>.filesystem]` 바로 아래에 둔다.
  `":workspace_roots"` 안에 넣으면 `did not match any variant of untagged enum` 으로 거부된다
- **특수 토큰(`:minimal` 등)은 검증되지 않는다.** 오타를 내도 설정이 그대로 로드되므로
  조용히 무시될 수 있다. 공식 레퍼런스에 있는 토큰만 쓸 것
- `--unrestricted` 는 `sandbox_mode` 뿐 아니라 **`default_permissions` 도 함께 덮어야** 한다.
  안 그러면 `[permissions.locked]` 가 살아남아 파일 접근이 계속 막힌다

---

## Codex 위험 권한

⚠️ `codex/config.toml` 의 기본값은 **안전한 쪽**이다.

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

## 보안

- **`~/.claude.json` 은 절대 커밋하지 않는다.** MCP 의 OAuth 베어러 토큰과 API 키가 평문으로 들어있다. `.gitignore` 로 막아뒀다.
- **`codex mcp add --env` 는 API 키를 `~/.codex/config.toml` 에 평문으로 쓴다.** 이 파일도 절대 레포에 넣지 않는다.
- `scripts/extract_sections.py` 는 진단용 diff 도구라 `*_KEY`, `*_TOKEN`, `env` 테이블 값을 자동으로 `***` 로 가린다.
- 실제 키는 `.env.local` 에만 둔다. 커밋 전 `git diff` 로 확인할 것.

### gitleaks pre-commit 훅

사람 눈으로 `git diff` 를 확인하는 건 언젠가 뚫린다. [gitleaks](https://github.com/gitleaks/gitleaks) 로 자동화해뒀다.

```bash
brew install gitleaks
./scripts/install-gitleaks.sh            # 이 레포에만
./scripts/install-gitleaks.sh --global   # 앞으로 만드는 모든 레포에도
```

- 훅 본체는 `.githooks/pre-commit` 하나뿐이다. 이 레포는 `core.hooksPath=.githooks` 로,
  다른 레포는 `~/.config/git/hooks/pre-commit` 심링크로 **같은 파일**을 쓴다.
- 스테이징된 내용만 검사한다(`gitleaks git --pre-commit --staged`). 걸리면 커밋이 중단된다.
- 룰은 gitleaks 기본 룰셋 + `.gitleaks.toml` 의 예외. `.env.example` 은 플레이스홀더뿐이라 제외했다.
- 오탐이면 `--no-verify` 로 우회하지 말고 `.gitleaks.toml` 의 `allowlist` 나 줄 끝 `# gitleaks:allow` 로 처리한다.
- 히스토리 전체 검사: `gitleaks git . --redact`
- ⚠️ `--global` 은 전역 `core.hooksPath` 를 켜므로 **기존 레포의 `.git/hooks/` 안 훅이 무시된다.**
  husky 처럼 레포별로 `core.hooksPath` 를 잡는 도구는 영향이 없다. 스크립트가 적용 전에 확인을 받는다.

---

## 알려진 한계

- **GitHub MCP 는 등록하지 않는다.** `api.githubcopilot.com/mcp/` 의 인증 서버가
  동적 클라이언트 등록(RFC 7591)을 지원하지 않아 codex-cli 0.144.6 과 Claude Code 양쪽 다
  `does not support dynamic client registration` 으로 실패한다. `/mcp` 의 Authenticate 도 같은 지점에서 막힌다.
  붙이려면 둘 중 하나가 필요한데 지금 `mcp.json` 스키마로는 표현할 수 없어서 제외했다.
  - PAT 를 헤더로: `claude mcp add --transport http github <url> --header "Authorization: Bearer <PAT>"`
    (Claude Code 문서가 GitHub 용으로 지목한 경로)
  - OAuth App 을 사전 등록하고 `--client-id --client-secret --callback-port` 로 지정
    (Claude Code 는 지원하지만 GitHub 이 자체 등록 앱을 받아주는지는 미확인)

  되살리려면 `mcp_reconcile.py` 의 `norm_desired`/`add_argv` 에 헤더 또는 OAuth 플래그 지원을 넣어야 한다.
  그 전까지 GitHub 작업은 `gh` CLI 로 한다.
- **`omo@sisyphuslabs` 는 자동 복원되지 않는다.** Codex 마켓플레이스가 전부 로컬 경로이고
  이 마켓플레이스는 git 저장소가 아니라 원본 URL 이 기록돼 있지 않다. 새 기기에서는 직접 설치해야 한다.
  `install-codex.sh` 는 미설치를 감지해 경고만 낸다.
- **`codex mcp add` 는 `config.toml` 전체를 자기 포맷으로 다시 쓴다.** 섹션 순서가 바뀌고
  `120` 이 `120.0` 이 되는 식이다. 값은 보존되므로 문제는 없지만 diff 가 커 보일 수 있다.
- **플러그인 상태 판정은 `claude plugin list --json` 에 의존한다.** JSON 을 쓸 수 없는 버전
  (또는 `jq` 미설치)에서는 사람용 출력의 `❯` 아이콘과 `Status:` 문구를 파싱하는 폴백으로 내려간다.
  이 폴백은 CLI 가 표시를 바꾸면 깨지므로, 그때는 경고를 찍고 오탐 가능성을 알린다.
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
