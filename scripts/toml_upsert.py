#!/usr/bin/env python3
"""오버레이 TOML 에 선언된 키만 대상 TOML 에 덮어쓴다.

대상 파일의 나머지 줄(다른 섹션, 주석, 공백, 프로그램이 생성한 상태)은
바이트 그대로 통과한다. 코덱스가 config.toml 에 계속 써 넣는
hooks.state / marketplaces / projects / tui / agents 같은 블록을 보존하기 위한 것이다.

사용법:
    toml-upsert.py --overlay a.toml [--overlay b.toml] < current.toml > new.toml
    toml-upsert.py --overlay a.toml --in-place ~/.codex/config.toml

오버레이는 나중에 지정한 것이 앞선 것을 덮는다.
값은 오버레이의 원문 줄을 그대로 옮기므로 여러 줄 배열·삼중따옴표도 유지된다.
오버레이의 주석은 옮기지 않는다(설명은 레포에만 남는다).
"""

import argparse
import sys
from collections import OrderedDict

ROOT = None  # 루트 섹션(첫 [header] 이전)을 가리키는 키


class Entry:
    """논리적 한 덩어리. kind 는 'header' | 'keyval' | 'other'."""

    __slots__ = ("kind", "key", "lines")

    def __init__(self, kind, key, lines):
        self.kind = kind
        self.key = key
        self.lines = lines


def _scan(line, in_triple, depth):
    """한 줄을 훑어 (문자열 밖 '=' 위치, 갱신된 in_triple, 갱신된 depth) 를 낸다.

    in_triple 은 None 이거나 여는 삼중따옴표 문자열("\"\"\"" 또는 "'''").
    depth 는 아직 닫히지 않은 [ 와 { 의 개수.
    """
    eq_pos = -1
    i = 0
    n = len(line)
    in_str = None  # 홑따옴표 문자열이면 "'" 겹따옴표면 '"'
    while i < n:
        ch = line[i]

        if in_triple:
            if line.startswith(in_triple, i):
                i += 3
                in_triple = None
                continue
            i += 1
            continue

        if in_str:
            if in_str == '"' and ch == "\\":
                i += 2  # 기본 문자열에서만 이스케이프가 유효
                continue
            if ch == in_str:
                in_str = None
            i += 1
            continue

        # 여기부터는 문자열 밖
        if line.startswith('"""', i) or line.startswith("'''", i):
            in_triple = line[i : i + 3]
            i += 3
            continue
        if ch in ('"', "'"):
            in_str = ch
            i += 1
            continue
        if ch == "#":
            break  # 줄 끝까지 주석
        if ch in "[{":
            depth += 1
        elif ch in "]}":
            depth -= 1
        elif ch == "=" and eq_pos < 0 and depth == 0:
            eq_pos = i
        i += 1

    return eq_pos, in_triple, depth


def parse(text):
    """텍스트를 Entry 목록으로 나눈다. 원문 줄은 하나도 잃지 않는다."""
    lines = text.splitlines(keepends=True)
    entries = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        stripped = line.strip()

        if not stripped or stripped.startswith("#"):
            entries.append(Entry("other", None, [line]))
            i += 1
            continue

        eq_pos, in_triple, depth = _scan(line, None, 0)

        # 값이 여러 줄에 걸치면 depth 가 0 으로 돌아오고 삼중따옴표가 닫힐 때까지 이어 붙인다
        block = [line]
        i += 1
        while (depth > 0 or in_triple) and i < n:
            block.append(lines[i])
            _, in_triple, depth = _scan(lines[i], in_triple, depth)
            i += 1

        if stripped.startswith("[") and eq_pos < 0:
            name = stripped.strip("[]").strip()
            entries.append(Entry("header", name, block))
        elif eq_pos >= 0:
            key = line[:eq_pos].strip().strip("\"'")
            entries.append(Entry("keyval", key, block))
        else:
            entries.append(Entry("other", None, block))

    return entries


def load_overlay(paths):
    """오버레이 파일들을 {섹션명: OrderedDict(키 -> 원문 줄들)} 로 읽는다."""
    overlay = OrderedDict()
    for path in paths:
        with open(path, "r", encoding="utf-8") as fh:
            entries = parse(fh.read())
        section = ROOT
        for entry in entries:
            if entry.kind == "header":
                section = entry.key
                overlay.setdefault(section, OrderedDict())
            elif entry.kind == "keyval":
                overlay.setdefault(section, OrderedDict())[entry.key] = entry.lines
    # 키가 하나도 없는 빈 섹션은 만들지 않는다
    return OrderedDict((k, v) for k, v in overlay.items() if v)


def _ensure_trailing_newline(block):
    if block and not block[-1].endswith("\n"):
        block = block[:-1] + [block[-1] + "\n"]
    return block


def upsert(text, overlay):
    """overlay 의 키만 text 에 반영한 새 텍스트를 낸다."""
    entries = parse(text)
    out = []
    section = ROOT
    seen = {}  # 섹션명 -> 이미 덮어쓴 키 집합
    # 섹션 본문이 끝나는 지점(다음 헤더 직전의 마지막 비어있지 않은 줄 다음)을 찾기 위해
    # 출력 버퍼에 섹션 경계를 기록한다
    pending_tail = []  # 섹션 끝 공백/주석은 새 키 뒤로 밀어낸다

    def flush_missing(sec):
        """섹션 sec 에서 아직 못 쓴 오버레이 키를 붙인다."""
        if sec not in overlay:
            return
        done = seen.setdefault(sec, set())
        for key, block in overlay[sec].items():
            if key not in done:
                out.extend(_ensure_trailing_newline(list(block)))
                done.add(key)

    for entry in entries:
        if entry.kind == "header":
            flush_missing(section)
            out.extend(pending_tail)
            pending_tail = []
            section = entry.key
            seen.setdefault(section, set())
            out.extend(entry.lines)
            continue

        if entry.kind == "keyval":
            out.extend(pending_tail)
            pending_tail = []
            table = overlay.get(section)
            if table is not None and entry.key in table:
                done = seen.setdefault(section, set())
                if entry.key in done:
                    continue  # 중복 정의는 첫 번째만 남기고 버린다
                out.extend(_ensure_trailing_newline(list(table[entry.key])))
                done.add(entry.key)
            else:
                out.extend(entry.lines)
            continue

        # 공백/주석: 섹션 끝에 몰려 있으면 새로 넣을 키보다 뒤로 보낸다
        pending_tail.extend(entry.lines)

    flush_missing(section)
    out.extend(pending_tail)

    # 대상에 아예 없던 섹션을 뒤에 붙인다
    for sec, table in overlay.items():
        if sec in seen:
            continue
        if out and not out[-1].endswith("\n"):
            out.append("\n")
        if out and out[-1].strip():
            out.append("\n")
        if sec is not ROOT:
            out.append("[%s]\n" % sec)
        for block in table.values():
            out.extend(_ensure_trailing_newline(list(block)))

    return "".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--overlay", action="append", required=True,
                    help="반영할 키를 담은 TOML. 여러 번 지정하면 뒤가 앞을 덮는다.")
    ap.add_argument("--in-place", metavar="FILE",
                    help="stdin/stdout 대신 이 파일을 읽고 같은 자리에 쓴다.")
    args = ap.parse_args()

    overlay = load_overlay(args.overlay)

    if args.in_place:
        try:
            with open(args.in_place, "r", encoding="utf-8") as fh:
                current = fh.read()
        except FileNotFoundError:
            current = ""
        result = upsert(current, overlay)
        with open(args.in_place, "w", encoding="utf-8") as fh:
            fh.write(result)
    else:
        sys.stdout.write(upsert(sys.stdin.read(), overlay))


if __name__ == "__main__":
    main()
