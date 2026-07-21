# <프로젝트 이름>

<한두 문장으로 이 프로젝트가 무엇인지. 예: Next.js App Router 기반 사내 대시보드.>

## 스택

- <프레임워크 / 런타임 예: Next.js 15 App Router, React 19>
- <상태 관리 예: TanStack Query>
- <스타일 예: Tailwind CSS>
- <패키지 매니저 예: pnpm>

## 명령어

여기 적힌 명령을 쓴다. 비슷한 다른 명령을 만들어 쓰지 않는다.

```bash
<pnpm dev>          # 개발 서버
<pnpm build>        # 빌드
<pnpm typecheck>    # 타입 검사
<pnpm lint>         # 린트
<pnpm test>         # 단위 테스트
<pnpm test:e2e>     # E2E
```

## 디렉터리

- `<src/components/ui>` — <공용 UI. 새로 만들기 전에 여기부터 찾을 것>
- `<src/lib>` — <공용 유틸>
- `<src/app>` — <라우트>

## 규칙

- <src/components/ui 의 컴포넌트를 우선 재사용한다. 비슷한 걸 새로 만들지 않는다.>
- <src/generated 는 수정하지 않는다. 생성물이다.>
- <DB 마이그레이션은 확인 없이 만들지 않는다.>
- <새 의존성을 추가하기 전에 먼저 묻는다.>

## Git

- <기준 브랜치: dev>
- <PR 대상: dev>
- <커밋 메시지: Conventional Commits>

<!--
  이 파일은 Codex 와 Claude Code 가 모두 읽는다.
  프로젝트 공통 정보는 여기 한 곳에만 두고,
  Claude 에만 해당하는 내용은 CLAUDE.md 에 적는다.
-->
