# 플러그인 & 마켓플레이스

이 PC에 설치된 Claude Code 마켓플레이스와 플러그인 목록.
`install.sh`가 아래를 자동으로 재현합니다 (`claude` CLI 필요).

## 마켓플레이스

| 이름 | 소스 |
|------|------|
| `claude-plugins-official` | `anthropics/claude-plugins-official` (GitHub 공식, 257개 제공) |
| `omc` | `https://github.com/Yeachan-Heo/oh-my-claudecode.git` |

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode.git
```

## 설치된 플러그인

| 플러그인 | 마켓플레이스 | 상태 |
|----------|--------------|------|
| `oh-my-claudecode` | `omc` | enabled (v4.15.4) |

```bash
claude plugin install oh-my-claudecode@omc -s user
```

> `oh-my-claudecode` 플러그인은 자체 MCP 서버(`plugin:oh-my-claudecode:t`)를
> 함께 제공하므로, 플러그인만 설치하면 그 도구들은 자동으로 딸려옵니다.
> (별도 `claude mcp add` 불필요)

## 확인

```bash
claude plugin list
```
