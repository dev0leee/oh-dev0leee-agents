# claude-setup

내 Claude Code + [oh-my-claudecode(OMC)](https://github.com/Yeachan-Heo/oh-my-claudecode) 설정 백업.
새 PC에서 동일한 환경을 재현하기 위한 저장소입니다.

## 구성

```
config/
  CLAUDE.md         # 전역 OMC 설정 (~/.claude/CLAUDE.md)
  settings.json     # 전역 설정: 상태줄, 플러그인, 팀 플래그 (~/.claude/settings.json)
  omc-config.json   # OMC 기본값: 실행 모드, 팀 설정 (~/.claude/.omc-config.json)
hud/
  omc-hud-min.mjs   # 최소 statusline: "ctx: NN%  msg: NN%" (로컬 계산, 토큰 0)
plugins/
  plugins.md        # 마켓플레이스 + 설치 플러그인 목록/재설치 명령
mcp/
  mcp-servers.md    # MCP 서버 재설치 명령 (API 키는 플레이스홀더)
install.sh          # 마켓플레이스·플러그인·MCP·설정을 한 번에 복원하는 스크립트
.env.example        # 키 템플릿 (.env.local 로 복사해 실제 값 입력)
```

## 현재 설정 요약

- **OMC 버전:** 4.15.4 (플러그인)
- **기본 실행 모드:** `ultrawork`
- **에이전트 팀:** 활성화 (에이전트 3, provider `claude`)
- **HUD 상태줄:** 최소 모드 (`ctx: NN%  msg: NN%` 만 표시)
  - `ctx` = 전체 컨텍스트 사용률, `msg` = 대화 메시지 사용률(≈ 전체 − 오버헤드)
  - 오버헤드 기본 25k, `OMC_MSG_OVERHEAD_TOKENS` 로 조정 가능
- **마켓플레이스:** `claude-plugins-official`, `omc`
- **플러그인:** `oh-my-claudecode` (enabled)
- **MCP 서버:** Context7, Filesystem, Exa, GitHub, Lazyweb
  (+ `oh-my-claudecode` 플러그인이 자체 제공하는 `t` 서버)

## 새 PC에서 복원하기

```bash
git clone https://github.com/dev0leee/oh-dev0leee-agents.git
cd oh-dev0leee-agents
cp .env.example .env.local   # EXA_API_KEY, FILESYSTEM_DIR 채우기
bash install.sh              # 설정 복원 + .env.local 로 MCP 자동 등록
```

이후 안내되는 수동 단계(플러그인 설치, GitHub MCP 로그인 등)를 따르세요.
실제 키는 `.env.local`(gitignore)에만 두고 절대 커밋하지 마세요.

## ⚠️ 보안

- 이 저장소에는 **API 키·토큰이 들어있지 않습니다.** MCP 키는 플레이스홀더입니다.
- `~/.claude.json`(Exa 키·세션 상태 포함), `sessions/`, `history.jsonl` 등은
  의도적으로 제외했습니다. `.gitignore`가 실제 시크릿 파일 유입을 막습니다.
- 커밋 전 항상 `git diff`로 키가 섞이지 않았는지 확인하세요.
