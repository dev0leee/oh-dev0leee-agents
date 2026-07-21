#!/usr/bin/env python3
"""TOML 에서 "우리가 소유하지 않은" 부분만 원문 그대로 뽑는다.

install-codex.sh 가 병합한 뒤, 코덱스가 런타임에 써 넣은 블록
(hooks.state / marketplaces / projects / tui / agents / mcp_servers / notify 등)이
한 글자도 안 바뀌었는지 before/after 를 diff 해서 확인하는 데 쓴다.

사용법:
    extract_sections.py --preserved ~/.codex/config.toml
    extract_sections.py --preserved --overlay codex/config.toml FILE

--overlay 를 생략하면 레포의 codex/config.toml 과 codex/unrestricted.toml 을 소유 목록으로 쓴다.
"""

import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from toml_upsert import ROOT, load_overlay, parse  # noqa: E402

# ~/.codex/config.toml 에는 codex mcp add 가 써 넣은 API 키가 평문으로 들어있다.
# 이 도구는 그 파일을 diff 하는 용도라서, 값을 그대로 뱉으면 로그·터미널·붙여넣기로 새어나간다.
# 기본적으로 값을 가린다.
SECRET_KEY = re.compile(r"(KEY|TOKEN|SECRET|PASSWORD|PASSWD|AUTH|CREDENTIAL|BEARER)", re.I)


def _redact(section, lines):
    """민감해 보이는 키의 값을 *** 로 바꾼다. 키 이름과 구조는 남긴다."""
    in_env = section is not ROOT and re.search(r"(^|\.)env$", section or "")
    out = []
    for line in lines:
        head, sep, _ = line.partition("=")
        if sep and (in_env or SECRET_KEY.search(head)):
            out.append(f"{head.rstrip()} = \"***\"\n")
        else:
            out.append(line)
    return out

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OVERLAYS = [
    os.path.join(REPO, "codex", "config.toml"),
    os.path.join(REPO, "codex", "unrestricted.toml"),
]


def preserved(text, overlay, redact=True):
    """소유하지 않은 항목의 원문 줄만 이어 붙인다.

    공백/주석은 비교 잡음이라 버리고, 헤더는 소속을 알 수 있게 남긴다.
    redact=True 면 API 키 같은 값을 *** 로 가린다(기본값).
    """
    out = []
    section = ROOT
    for entry in parse(text):
        if entry.kind == "header":
            section = entry.key
            if section not in overlay:
                out.extend(entry.lines)
        elif entry.kind == "keyval":
            table = overlay.get(section)
            if table is None or entry.key not in table:
                out.extend(_redact(section, entry.lines) if redact else entry.lines)
        # 'other'(공백·주석)는 비교에서 제외
    return "".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("file")
    ap.add_argument("--preserved", action="store_true",
                    help="소유하지 않은 부분만 출력한다 (현재 유일한 모드)")
    ap.add_argument("--overlay", action="append",
                    help="소유 목록으로 쓸 TOML. 생략하면 레포의 codex/*.toml 을 쓴다.")
    args = ap.parse_args()

    overlay = load_overlay(args.overlay or DEFAULT_OVERLAYS)
    with open(args.file, "r", encoding="utf-8") as fh:
        sys.stdout.write(preserved(fh.read(), overlay))


if __name__ == "__main__":
    main()
