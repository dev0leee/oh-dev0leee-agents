<!--
  이 파일은 AI-SETUP 레포의 원본입니다. ~/.claude/CLAUDE.md 가 여기로 심볼릭 링크됩니다.
  아래 "공통 규칙" 은 instructions/AGENTS.md 와 의도적으로 중복됩니다.
  공통 내용을 고칠 때는 두 파일을 함께 수정하세요.
  OMC:START ~ OMC:END 블록은 /oh-my-claudecode:omc-setup 이 다시 씁니다. 그 안에 직접 쓰지 마세요.
-->

# 공통 규칙

## 작업 범위

- 기본 작업 범위는 **현재 프로젝트 디렉터리**다.
- 최대 범위는 `~/Desktop/working` 까지다.
- 이 범위를 벗어나면 읽기든 쓰기든 명령 실행이든 **사용자 허락 없이 하지 않는다.**
  필요해 보이면 조용히 접근하지 말고, 어떤 경로가 왜 필요한지 말하고 멈춘다.
- 예외는 사용자가 직접 요청한 설정 작업뿐이다
  (AI-SETUP 저장소의 `scripts/install.sh` 처럼 `~/.claude` · `~/.codex` 를 손대는 경우).
- 범위 밖 경로에 접근할 수 있다는 사실이 허락은 아니다.

## 코드를 고치기 전에

- 고치려는 파일과 그 주변 코드를 먼저 읽는다. 추측으로 수정하지 않는다.
- 새로 만들기 전에 이미 있는 컴포넌트·유틸·훅을 먼저 찾는다.
- 라이브러리를 임의로 추가하지 않는다. 필요하면 먼저 묻는다.
- 규모가 있는 작업은 먼저 계획을 세우고 시작한다.

## 코드를 쓸 때

- 주변 코드의 스타일·네이밍·구조를 따른다. 나만의 패턴을 새로 만들지 않는다.
- 불필요한 추상화를 만들지 않는다. 지금 필요한 것만 만든다.
- 자명한 코드에 주석을 달지 않는다. 왜 그렇게 했는지가 안 보일 때만 쓴다.
- 타입 오류를 남기지 않는다.

## 끝내기 전에

- 관련 테스트와 lint, typecheck 를 실행한다.
- 실패하면 실패했다고 말한다. 통과한 척하지 않는다.
- 실행하지 못한 검증이 있으면 무엇을 못 했는지 명시한다.
- 마지막에 변경한 파일과 검증 결과를 한글로 요약한다.

<!-- OMC:START -->
<!-- OMC:VERSION:4.15.4 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<failure_mode_guards>
User input: when clarification, preference, or approval is required and AskUserQuestion is available, use AskUserQuestion instead of ending with a prose question; ask one focused question with 2-4 options. Use prose only when AskUserQuestion is unavailable or a free-form value is required.
Session/worktree continuity: before editing after resume/compaction or inside a linked worktree, re-check `git status --short --branch`, current cwd, and relevant `.omc/state/` or `.omc/handoffs/` artifacts so work does not continue on the wrong branch or stale context.
No fake completion: TODO-style placeholder notes, `test.skip`/`.only`, stub tests, and unimplemented branches are blockers, not evidence. Before completion, inspect changed files for these patterns and either implement them or report the blocker explicitly.
</failure_mode_guards>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State root: `.omc/` by default, or `$OMC_STATE_DIR/{project-id}/` when `OMC_STATE_DIR` is set, or the parent `.omc/` when a `.omc-workspace` marker anchors a multi-repo workspace. Runtime state includes `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`, `.omc/artifacts/`, `.omc/handoffs/`, and `.omc/ultragoal/`. These are ignored operational artifacts by default; `.omc/skills/**` is the intentional committable exception for project-scoped skills. In linked git worktrees, local `.omc/` state is removed with the worktree unless centralized via `OMC_STATE_DIR`.
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->
