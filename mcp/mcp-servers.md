# MCP 서버 설정

이 PC에 구성한 MCP 서버 목록과 재설치 명령입니다.
`claude` CLI가 있어야 하며, 각 서버는 프로젝트/사용자 범위로 추가됩니다.

> ⚠️ **주의:** Exa 서버는 API 키가 필요합니다. 아래 `<YOUR_EXA_API_KEY>`를
> 본인 키([exa.ai](https://exa.ai)에서 발급)로 바꾼 뒤 실행하세요.
> 실제 키를 이 파일에 절대 커밋하지 마세요.

## 권장: `.env` 로 자동 등록

키를 손으로 넣는 대신, 루트의 `.env` 에 넣고 `install.sh` 가 자동 등록하게 할 수 있습니다.

```bash
cp .env.example .env.local   # EXA_API_KEY, FILESYSTEM_DIR 채우기
bash install.sh              # .env.local 을 읽어 아래 서버들을 user 스코프로 자동 등록
```

`.env.local` / `.env` 는 `.gitignore` 로 저장소에 올라가지 않습니다.
`install.sh` 는 아래 서버를 `-s user`(모든 프로젝트에서 사용) 스코프로 등록합니다.
아래는 수동 등록용 원본 명령입니다.

> 참고: `plugin:oh-my-claudecode:t` 서버는 OMC **플러그인이 자체 제공**하므로
> 여기서 따로 추가하지 않습니다 (플러그인 설치 시 자동 포함).

## 1. Context7 — 문서/코드 컨텍스트 (키 불필요)

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
```

## 2. Filesystem — 확장 파일 접근 (키 불필요)

디렉터리 인자를 본인 작업 경로로 바꾸세요.

```bash
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem <YOUR_PROJECT_DIR>
```

## 3. Exa — 웹 검색 (API 키 필요)

```bash
claude mcp add exa -e EXA_API_KEY=<YOUR_EXA_API_KEY> -- npx -y exa-mcp-server
```

## 4. GitHub — HTTP 원격 (토큰 불필요, 최초 사용 시 OAuth 인증)

```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp/
```

> GitHub는 최초 연결 시 `/mcp` 메뉴에서 github를 선택해 로그인해야 활성화됩니다.

## 5. Lazyweb — 제품/UI 작업 도구 (HTTP)

```bash
claude mcp add --transport http lazyweb https://www.lazyweb.com/mcp
```

> 최초 사용 시 로그인/인증 안내가 나오면 따르세요.

## 확인

```bash
claude mcp list
```
