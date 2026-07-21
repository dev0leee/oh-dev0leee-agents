# 플러그인 & 마켓플레이스

이 PC에 설치된 Claude Code 마켓플레이스와 플러그인 목록.
`install.sh`가 아래를 자동으로 재현합니다 (`claude` CLI 필요).

## 마켓플레이스

| 이름 | 소스 |
|------|------|
| `claude-plugins-official` | `anthropics/claude-plugins-official` (GitHub 공식, 257개 제공) |
| `omc` | `https://github.com/Yeachan-Heo/oh-my-claudecode.git` |
| `last30days-skill` | `mvanhorn/last30days-skill` |

```bash
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin marketplace add https://github.com/Yeachan-Heo/oh-my-claudecode.git
claude plugin marketplace add mvanhorn/last30days-skill
```

## 설치된 플러그인

| 플러그인 | 마켓플레이스 | 상태 |
|----------|--------------|------|
| `oh-my-claudecode` | `omc` | enabled (v4.15.4) |
| `last30days` | `last30days-skill` | disabled (v3.11.0) |

```bash
claude plugin install oh-my-claudecode@omc -s user

# last30days 는 설치만 해두고 평소엔 꺼둡니다 (필요할 때 enable)
claude plugin install last30days@last30days-skill -s user
claude plugin disable last30days@last30days-skill -s user
```

> `oh-my-claudecode` 플러그인은 자체 MCP 서버(`plugin:oh-my-claudecode:t`)를
> 함께 제공하므로, 플러그인만 설치하면 그 도구들은 자동으로 딸려옵니다.
> (별도 `claude mcp add` 불필요)

### last30days 는 무엇인가

이름은 "skill" 이지만 **설치 단위는 플러그인**입니다. 안에 스킬(`skills/last30days`) 하나와
훅, 자체 MCP 서버(Go), 에이전트가 함께 들어 있어서 스킬 폴더 하나로는 배포가 안 됩니다.

레딧·X·유튜브·틱톡·인스타그램·해커뉴스·Polymarket·GitHub 등 10여 곳을 훑어 주제를 리서치하는
도구입니다. 에디터 추천이 아니라 업보트·좋아요·실제 베팅 금액으로 점수를 매깁니다.

평소에는 꺼둡니다(컨텍스트 절약). 쓸 때만 켜세요.

```bash
claude plugin enable last30days@last30days-skill -s user   # 켜기
claude plugin disable last30days@last30days-skill -s user  # 다시 끄기
```

## 확인

```bash
claude plugin list
```
