#!/usr/bin/env python3
"""claude/settings.json 과 프로젝트 템플릿의 금지선이 어긋나지 않는지 검사한다.

두 파일은 목적이 다르다. 전역(claude/settings.json)은 계정 전체에 걸리는
금지선이고, 템플릿(templates/project/.claude/settings.json)은 새 프로젝트에
복사되어 그 프로젝트의 허용선(allow, defaultMode)을 정한다.

deny/ask 만 양쪽에 중복해서 둔다. 프로젝트 설정만 열어봐도 안전선이 보이게
하려는 것이다. 실제로 전역 deny 가 우선하므로 런타임 동작은 전역이 지배하지만,
템플릿은 전역 설정이 없는 기기나 CI 로도 복사되기 때문에 그때는 이 목록이
유일한 방어선이 된다.

문제는 이 중복이 손으로 관리된다는 것이다. 실제로 전역에 DB 파괴 명령과
force push 를 추가할 때 템플릿을 빼먹어 한동안 어긋나 있었다
(`Bash(git push *)` 의 공백 버그까지 템플릿에만 남아 있었다).
한쪽만 고치면 여기서 깨진다.

    python3 -m unittest discover -s tests -v
"""

import json
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLOBAL = os.path.join(REPO, "claude", "settings.json")
TEMPLATE = os.path.join(REPO, "templates", "project", ".claude", "settings.json")

# 템플릿이 자기 것으로 갖는 키. 프로젝트마다 무엇을 허용할지가 달라서 공유하지 않는다.
TEMPLATE_ONLY = {"allow", "defaultMode"}
# 전역이 자기 것으로 갖는 최상위 키. 프로젝트 단위로 정할 값이 아니다.
GLOBAL_ONLY_TOP = {"env", "statusLine", "tui"}


def load(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


class DenyAskParity(unittest.TestCase):
    def setUp(self):
        self.g = load(GLOBAL)["permissions"]
        self.t = load(TEMPLATE)["permissions"]

    def test_deny_identical(self):
        self.assertEqual(
            self.g["deny"], self.t["deny"],
            "deny 목록이 어긋났다. 한쪽만 고쳤으면 다른 쪽도 같이 고칠 것.",
        )

    def test_ask_identical(self):
        self.assertEqual(
            self.g["ask"], self.t["ask"],
            "ask 목록이 어긋났다. 한쪽만 고쳤으면 다른 쪽도 같이 고칠 것.",
        )

    def test_bare_dangerous_commands_are_covered(self):
        # "Bash(git push *)" 처럼 뒤에 공백을 두면 공백+인자가 있어야 매치돼서
        # 인자 없는 `git push` 가 그대로 빠져나간다. 인자 없이도 위험한 명령은
        # 공백 없는 glob 이어야 한다. 반대로 `rm -rf` 나 `sudo` 는 인자가 없으면
        # 아무 일도 안 하므로 " *)" 가 맞다 — 그래서 일괄 규칙이 아니라 목록이다.
        for cmd in ("git push", "npm publish"):
            self.assertIn(
                f"Bash({cmd}*)", self.g["deny"],
                f"`{cmd}` 는 인자 없이도 위험하다. "
                f"'Bash({cmd} *)' 처럼 공백을 두면 인자 없는 호출이 빠져나간다.",
            )


class OwnershipBoundary(unittest.TestCase):
    """서로의 영역을 침범하지 않는지 본다. 중복은 deny/ask 로만 한정한다."""

    def test_template_keeps_its_own_allow_side(self):
        t = load(TEMPLATE)["permissions"]
        for key in TEMPLATE_ONLY:
            self.assertIn(key, t, f"템플릿에 {key} 가 없다")
            self.assertNotIn(key, load(GLOBAL)["permissions"],
                             f"{key} 는 프로젝트마다 다르므로 전역에 두지 않는다")

    def test_template_has_no_global_only_keys(self):
        t = load(TEMPLATE)
        self.assertEqual(
            set(t) & GLOBAL_ONLY_TOP, set(),
            "statusLine / env / tui 는 계정 단위 설정이라 템플릿에 두지 않는다",
        )

    def test_install_claude_declares_every_global_key(self):
        # install-claude.sh 의 소유권 목록에 빠진 키가 있으면 설치가 멈추도록
        # 되어 있다. 그 가드가 실제 파일과 맞는지 여기서도 확인한다.
        with open(os.path.join(REPO, "scripts", "install-claude.sh"),
                  encoding="utf-8") as fh:
            script = fh.read()
        declared = set()
        for line in script.splitlines():
            for var in ("SETTINGS_OWNED=", "SETTINGS_SHALLOW="):
                if line.startswith(var):
                    declared |= set(json.loads(line.split("=", 1)[1].strip("'")))
        self.assertEqual(
            set(load(GLOBAL)) - declared, set(),
            "claude/settings.json 의 키가 install-claude.sh 의 "
            "SETTINGS_OWNED / SETTINGS_SHALLOW 에 선언되지 않았다",
        )


if __name__ == "__main__":
    unittest.main()
