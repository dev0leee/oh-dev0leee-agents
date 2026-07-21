---
name: worktree
argument-hint: "<브랜치명> (예: feat/canvas-undo) — 생략하면 물어봄"
description: origin/dev(없으면 원격 기본 브랜치)를 기준으로 새 브랜치와 워크트리를 한 번에 만듭니다. 워크트리 경로는 .claude/worktrees/<브랜치명> 으로 브랜치 이름과 통일하고, .env.local 복사와 의존성 설치를 끝낸 뒤 세션을 그 워크트리로 옮겨 바로 개발 서버를 띄울 수 있는 상태로 넘겨줍니다. 새 작업을 격리된 폴더에서 시작할 때 사용합니다.
---

# /worktree — 새 브랜치 + 워크트리 생성

`$ARGUMENTS` 를 브랜치명으로 받아, **항상 최신 원격 기준 브랜치에서 갈라진** 브랜치와 워크트리를 만든다.
현재 체크아웃된 브랜치가 무엇이든, 작업 트리가 더럽든 상관없다 — 기준은 언제나 원격이다.

- 브랜치명: `$ARGUMENTS` 그대로
- 워크트리 경로: `<레포루트>/.claude/worktrees/<브랜치명>`
  브랜치명에 `/` 가 있으면 하위 폴더가 된다 (`feat/canvas-undo` → `.claude/worktrees/feat/canvas-undo`)

## 절차

### 0. 브랜치명 확보

`$ARGUMENTS` 가 비어 있으면 사용자에게 브랜치명을 묻고 멈춘다. 임의로 지어내지 않는다.

앞뒤 공백을 걷어낸 뒤 아래에 걸리면 진행하지 말고 이유를 알려준다.

- `git check-ref-format --branch "<브랜치명>"` 실패 → 깃이 안 받는 이름 (종료코드 128)
- `dev`, `main`, `master` → 이 스킬로 만들 이름이 아니다

### 1. 레포 루트와 기준 브랜치 판정

`git rev-parse --show-toplevel` 로 루트를 잡고, **이후 모든 경로는 그 아래 절대경로**로 쓴다.
(워크트리 안에서 이 스킬을 부르면 루트가 워크트리가 된다. `git rev-parse --path-format=absolute --git-common-dir` 의 부모가 진짜 주 레포이니, 워크트리 안이면 거기로 옮겨서 작업한다.)

기준 브랜치는 이 순서로 정한다.

1. `git ls-remote --exit-code --heads origin dev` 가 성공하면 → `origin/dev`
2. 아니면 `git symbolic-ref --short refs/remotes/origin/HEAD` (실패 시 `git remote set-head origin --auto` 후 재시도) → 그 결과

정했으면 그 브랜치만 받아온다.

```bash
git fetch origin <기준브랜치명>
```

어느 걸 기준으로 삼았는지는 마지막 보고에 반드시 적는다.

### 2. 사전 확인 — 하나라도 걸리면 아무것도 만들지 말 것

1. 로컬 브랜치 중복 — `git show-ref --verify --quiet refs/heads/<브랜치명>`
2. 원격 브랜치 중복 — `git ls-remote --exit-code --heads origin <브랜치명>`
3. 워크트리 경로 중복 — 폴더 존재 여부 + `git worktree list`

멈출 때는 실패했다고만 하지 말고, 이미 있는 워크트리면 그 경로를 알려줘 바로 `cd` 할 수 있게 한다.

### 3. 브랜치 + 워크트리 생성

한 줄로 브랜치 생성과 체크아웃이 같이 끝난다. `git branch` 를 따로 치지 않는다.

```bash
git worktree add --no-track -b "<브랜치명>" "<레포루트>/.claude/worktrees/<브랜치명>" <기준브랜치>
```

**`--no-track` 을 반드시 붙인다.** 빼면 새 브랜치가 `origin/dev` 를 업스트림으로 물어서,
나중에 `git pull` 이 dev 를 당겨오고 `git push` 가 dev 를 겨냥한다. 첫 푸시 때
`git push -u origin <브랜치명>` 으로 업스트림을 잡는 게 맞다.

여기서 실패하면 이후 단계로 넘어가지 않는다.

`.claude/worktrees/` 가 `.gitignore` 에 없으면 새 워크트리가 주 레포에 untracked 로 뜬다.
그럴 땐 파일을 고치지 말고, **보고에 "`.gitignore` 에 `.claude/worktrees/` 추가 권장"** 이라고 한 줄 남긴다.

### 4. 개발 준비

새 워크트리는 추적되는 파일만 있다 — `node_modules` 도 `.env*` 도 없다. 둘 다 채운다.

**환경 파일**: 루트의 `.env.local` 을 복사한다. 없으면 건너뛰고 **건너뛰었다고 보고에 적는다.** 조용히 넘어가지 않는다.

**의존성**: 루트의 락파일을 보고 패키지 매니저를 정한다.

| 락파일 | 명령 |
|---|---|
| `pnpm-lock.yaml` | `pnpm install --dir <워크트리>` |
| `yarn.lock` | `yarn --cwd <워크트리> install` |
| `bun.lockb` / `bun.lock` | `bun install --cwd <워크트리>` |
| `package-lock.json` | `npm ci --prefix <워크트리>` |
| 없음 | 설치 건너뛰고 보고에 적는다 |

- 1~2분 걸린다. Bash `timeout` 을 넉넉히(600000) 준다.
- `npm ci` 가 락파일 불일치로 실패하면 `npm install --prefix <워크트리>` 로 **한 번만** 재시도한다.
- 그래도 실패하면 워크트리는 지우지 않는다 — 이미 코드 편집은 되는 상태다. 실패 사실만 보고한다.

### 5. 세션을 새 워크트리로 이동 — 생략 금지

만들어만 두고 주 레포에 남아 있으면 안 된다. **`EnterWorktree` 로 세션을 새 워크트리에 넣는다.**
`cd` 는 답이 아니다 — Bash 의 작업 디렉터리는 다음 호출에서 유지되지만 세션 자체는 주 레포에 남는다.

`EnterWorktree` 는 지연 로딩(deferred)될 수 있다. 그러면 먼저 스키마를 받는다.

```
ToolSearch: select:EnterWorktree
```

그다음 **`name` 이 아니라 `path`** 로 부른다. `name` 은 새 워크트리를 또 만든다.

```
EnterWorktree(path: "<레포루트>/.claude/worktrees/<브랜치명>")
```

이동 후 `pwd` 와 `git branch --show-current` 로 확인하고, 결과를 보고에 적는다.
이동에 실패하면 워크트리는 그대로 두고, 실패 사실과 `cd` 명령을 보고한다.

### 6. 보고

짧게. 반드시 포함할 것:

- 브랜치명 / 어느 기준 브랜치의 어느 커밋(짧은 해시)에서 갈라졌는지
- 워크트리 절대경로
- `.env.local` 복사 여부, 의존성 설치 여부 — **건너뛰었거나 실패했으면 명시**
- **세션이 새 워크트리로 이동했다는 사실** (실패했으면 `cd` 명령을 대신 준다)

예시:

```
feat/canvas-undo 를 origin/dev(c48d519)에서 만들고 워크트리도 붙였음.
.env.local 복사·npm ci 끝나서 바로 dev 서버 돌릴 수 있음.
세션도 그 워크트리로 옮겼으니 이제 npm run dev 만 치면 된다.

  ~/Desktop/study/mood-me-fe/.claude/worktrees/feat/canvas-undo
```

## 하지 않는 것

- 커밋·푸시·PR 생성
- 워크트리 삭제 — 정리는 `git worktree remove <경로>` 를 직접 친다
- 기존 브랜치를 워크트리로 꺼내오기 — 이 스킬은 **새 브랜치 생성 전용**이다
- 주 레포의 작업 트리 건드리기 — 스테이징·스태시·체크아웃 전부 안 한다
