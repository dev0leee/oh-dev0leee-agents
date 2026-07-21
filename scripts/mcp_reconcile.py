#!/usr/bin/env python3
"""claude/mcp.json 을 원본 삼아 Claude/Codex 의 MCP 등록을 맞춘다.

멱등 규칙:
    현재에 없음        -> add
    현재와 선언이 다름 -> remove 후 add
    같음               -> 아무것도 안 함  (OAuth 세션 보존)

`add || true` 를 쓰지 않는 이유: 선언을 바꿔도 기존 등록이 갱신되지 않는다.
무조건 remove+add 하지 않는 이유: lazyweb 같은 HTTP 서버의 OAuth 인증이 매번 풀린다.

비교 대상
    stdio : type, command, args(순서 포함), env 키의 "집합"
    http  : type, url
비교하지 않는 것
    API 키의 실제 값 / OAuth 토큰 / 세션 / 서버가 자동 생성한 메타데이터
    (~/.claude.json 의 headers.Authorization 에는 실제 베어러 토큰이 들어있다. 절대 읽어서 비교하거나 출력하지 않는다.)

사용법:
    mcp_reconcile.py --tool claude [--yes] [--dry-run]
    mcp_reconcile.py --tool codex  [--yes] [--dry-run]
"""

import argparse
import json
import os
import subprocess
import sys
import tomllib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MCP_JSON = os.path.join(REPO, "claude", "mcp.json")
CLAUDE_STATE = os.path.expanduser("~/.claude.json")
CODEX_CONFIG = os.path.join(os.environ.get("CODEX_HOME", os.path.expanduser("~/.codex")), "config.toml")

DIM, OK, WARN, ERR, OFF = "\033[2m", "\033[32m", "\033[33m", "\033[31m", "\033[0m"
if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
    DIM = OK = WARN = ERR = OFF = ""


def say(sym, color, msg):
    print(f"  {color}{sym}{OFF} {msg}")


# ---------------------------------------------------------------- 선언(desired)

def load_desired(tool):
    with open(MCP_JSON, "r", encoding="utf-8") as fh:
        doc = json.load(fh)
    out = {}
    for name, spec in doc.get("servers", {}).items():
        if tool not in spec.get("targets", []):
            continue
        out[name] = spec
    return out


def missing_env(spec):
    """값이 없어서 등록을 건너뛰어야 하는 환경변수 이름들."""
    needed = list(spec.get("env", [])) + list(spec.get("requires", []))
    return [k for k in needed if not os.environ.get(k)]


def expand_args(spec):
    """args 안의 $VAR 를 펼친다. 경로용이며 시크릿은 여기 오지 않는다."""
    return [os.path.expandvars(a) for a in spec.get("args", [])]


def norm_desired(spec):
    if spec.get("type") == "http":
        return {"type": "http", "url": spec["url"]}
    return {
        "type": "stdio",
        "command": spec["command"],
        "args": expand_args(spec),
        "env_keys": sorted(spec.get("env", [])),
    }


# ---------------------------------------------------------------- 현재(actual)

def actual_claude():
    """~/.claude.json 의 user 스코프 MCP. headers 는 인증 정보라 읽지 않는다."""
    try:
        with open(CLAUDE_STATE, "r", encoding="utf-8") as fh:
            doc = json.load(fh)
    except FileNotFoundError:
        return {}
    out = {}
    for name, cfg in (doc.get("mcpServers") or {}).items():
        if cfg.get("type") == "http" or cfg.get("url"):
            out[name] = {"type": "http", "url": cfg.get("url")}
        else:
            out[name] = {
                "type": "stdio",
                "command": cfg.get("command"),
                "args": list(cfg.get("args") or []),
                "env_keys": sorted((cfg.get("env") or {}).keys()),
            }
    return out


def actual_codex():
    """(우리가 관리 가능한 서버, 플러그인이 제공하는 서버 이름들)

    codex mcp list --json 은 플러그인이 주는 서버와 config.toml 의 서버를
    출처 구분 없이 섞어서 보여준다. codex mcp add/remove 가 실제로 만지는 건
    config.toml 의 [mcp_servers.*] 뿐이므로 그쪽을 소유 기준으로 삼는다.
    """
    try:
        with open(CODEX_CONFIG, "rb") as fh:
            doc = tomllib.load(fh)
    except FileNotFoundError:
        doc = {}
    owned = {}
    for name, cfg in (doc.get("mcp_servers") or {}).items():
        if cfg.get("url"):
            owned[name] = {"type": "http", "url": cfg["url"]}
        else:
            env_keys = set((cfg.get("env") or {}).keys()) | set(cfg.get("env_vars") or [])
            owned[name] = {
                "type": "stdio",
                "command": cfg.get("command"),
                "args": list(cfg.get("args") or []),
                "env_keys": sorted(env_keys),
            }

    plugin_provided = set()
    try:
        res = subprocess.run(["codex", "mcp", "list", "--json"],
                             capture_output=True, text=True, timeout=60)
        if res.returncode == 0:
            for entry in json.loads(res.stdout):
                if entry.get("name") not in owned:
                    plugin_provided.add(entry["name"])
    except (OSError, ValueError, subprocess.SubprocessError):
        pass  # 목록을 못 얻으면 플러그인 감지만 포기한다
    return owned, plugin_provided


# ---------------------------------------------------------------- 명령 조립

def add_argv(tool, name, spec):
    """등록 명령의 argv. 셸을 거치지 않으므로 값 이스케이프 문제가 없다."""
    if tool == "claude":
        if spec.get("type") == "http":
            return ["claude", "mcp", "add", "-s", "user", "--transport", "http", name, spec["url"]]
        argv = ["claude", "mcp", "add", "-s", "user", name]
        for key in spec.get("env", []):
            argv += ["-e", f"{key}={os.environ[key]}"]
        return argv + ["--", spec["command"]] + expand_args(spec)

    if spec.get("type") == "http":
        return ["codex", "mcp", "add", name, "--url", spec["url"]]
    argv = ["codex", "mcp", "add", name]
    for key in spec.get("env", []):
        argv += ["--env", f"{key}={os.environ[key]}"]
    return argv + ["--", spec["command"]] + expand_args(spec)


def remove_argv(tool, name):
    if tool == "claude":
        return ["claude", "mcp", "remove", name, "-s", "user"]
    return ["codex", "mcp", "remove", name]


def redact(argv, spec):
    """로그용. env 값은 지우고 키 이름만 남긴다."""
    out, skip_next = [], False
    for tok in argv:
        if skip_next:
            out.append(tok.split("=", 1)[0] + "=***")
            skip_next = False
            continue
        if tok in ("-e", "--env"):
            skip_next = True
        out.append(tok)
    return " ".join(out)


def run(argv, spec, dry_run):
    if dry_run:
        say("·", DIM, f"(dry-run) {redact(argv, spec)}")
        return True
    res = subprocess.run(argv, capture_output=True, text=True)
    if res.returncode != 0:
        msg = (res.stderr or res.stdout).strip().splitlines()
        say("✗", ERR, f"{' '.join(argv[:4])} 실패: {msg[0] if msg else res.returncode}")
        return False
    return True


def confirm(prompt, assume_yes):
    if assume_yes:
        say("!", WARN, f"{prompt} → --yes 로 자동 승인")
        return True
    if not sys.stdin.isatty():
        say("!", WARN, f"{prompt} → 대화형 입력 불가로 건너뜀")
        return False
    return input(f"  {WARN}?{OFF} {prompt} [y/N] ").strip().lower() == "y"


# ---------------------------------------------------------------- 본체

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tool", choices=["claude", "codex"], required=True)
    ap.add_argument("--yes", action="store_true", help="확인 프롬프트를 자동 승인한다")
    ap.add_argument("--dry-run", action="store_true", help="실행하지 않고 무엇을 할지만 보여준다")
    args = ap.parse_args()

    desired = load_desired(args.tool)
    plugin_provided = set()
    if args.tool == "claude":
        actual = actual_claude()
    else:
        actual, plugin_provided = actual_codex()

    failed = 0
    for name, spec in desired.items():
        gaps = missing_env(spec)
        if gaps:
            say("!", WARN, f"{name}: {', '.join(gaps)} 미설정 → 건너뜀 (.env.local 채우고 재실행)")
            continue

        if name in plugin_provided:
            say("·", DIM, f"{name}: 플러그인이 제공 중 → 건드리지 않음")
            continue

        want = norm_desired(spec)
        have = actual.get(name)

        if have is None:
            if run(add_argv(args.tool, name, spec), spec, args.dry_run):
                say("✓", OK, f"{name}: 등록")
            else:
                failed += 1
            continue

        if have == want:
            say("·", DIM, f"{name}: 변경 없음")
            continue

        say("!", WARN, f"{name}: 설정이 달라졌다 → 교체")
        if want["type"] == "http":
            print(f"      {name} MCP configuration changed.")
            print("      The server will be replaced and OAuth authentication may be required again.")
            if not confirm("Continue?", args.yes):
                say("·", DIM, f"{name}: 사용자가 건너뜀")
                continue

        if not run(remove_argv(args.tool, name), spec, args.dry_run):
            failed += 1
            continue
        if run(add_argv(args.tool, name, spec), spec, args.dry_run):
            say("✓", OK, f"{name}: 교체 완료")
        else:
            failed += 1

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
