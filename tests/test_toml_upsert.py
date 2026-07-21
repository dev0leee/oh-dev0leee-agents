#!/usr/bin/env python3
"""scripts/toml_upsert.py 회귀 테스트.

핵심 계약: 오버레이에 선언한 키만 바뀌고, 나머지는 한 바이트도 안 바뀐다.
코덱스가 config.toml 에 계속 써 넣는 hooks.state / marketplaces / projects 를
설치할 때마다 날려먹지 않는다는 걸 보장하기 위한 것이다.

    python3 -m unittest discover -s tests -v
"""

import os
import sys
import tomllib
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "scripts"))

from extract_sections import preserved  # noqa: E402
from toml_upsert import load_overlay, upsert  # noqa: E402

FIXTURES = os.path.join(REPO, "tests", "fixtures")
BASE_OVERLAY = os.path.join(REPO, "codex", "config.toml")
UNRESTRICTED_OVERLAY = os.path.join(REPO, "codex", "unrestricted.toml")

# codex/config.toml 이 선언하는 값. 이 파일을 고치면 여기도 같이 고쳐야 한다.
EXPECTED = {
    "model": "gpt-5.5",
    "model_reasoning_effort": "medium",
    "service_tier": "fast",
    "approvals_reviewer": "user",
    "approval_policy": "on-request",
    "sandbox_mode": "workspace-write",
}
EXPECTED_FEATURES = {
    "goals": True,
    "unified_exec": True,
    "multi_agent": True,
    "plugin_hooks": True,
    "plugins": True,
    "js_repl": False,
}

FIXTURE_NAMES = [
    "empty.toml",
    "root-keys-present.toml",
    "no-features.toml",
    "comments-and-blanks.toml",
    "multiline-values.toml",
    "app-generated.toml",
]


def read(name):
    with open(os.path.join(FIXTURES, name), "r", encoding="utf-8") as fh:
        return fh.read()


class ContractForEveryFixture(unittest.TestCase):
    """모든 fixture 가 공통으로 만족해야 하는 4가지."""

    def setUp(self):
        self.overlay = load_overlay([BASE_OVERLAY])

    def test_result_reparses_as_toml(self):
        for name in FIXTURE_NAMES:
            with self.subTest(fixture=name):
                out = upsert(read(name), self.overlay)
                tomllib.loads(out)  # 문법을 깨뜨렸으면 여기서 터진다

    def test_owned_keys_take_expected_values(self):
        for name in FIXTURE_NAMES:
            with self.subTest(fixture=name):
                data = tomllib.loads(upsert(read(name), self.overlay))
                for key, want in EXPECTED.items():
                    self.assertEqual(data.get(key), want, f"{name}: {key}")
                for key, want in EXPECTED_FEATURES.items():
                    self.assertEqual(data["features"].get(key), want, f"{name}: features.{key}")

    def test_unowned_content_is_byte_identical(self):
        for name in FIXTURE_NAMES:
            with self.subTest(fixture=name):
                before = read(name)
                after = upsert(before, self.overlay)
                self.assertEqual(
                    preserved(before, self.overlay),
                    preserved(after, self.overlay),
                    f"{name}: 소유하지 않은 내용이 바뀌었다",
                )

    def test_applying_twice_equals_applying_once(self):
        for name in FIXTURE_NAMES:
            with self.subTest(fixture=name):
                once = upsert(read(name), self.overlay)
                twice = upsert(once, self.overlay)
                self.assertEqual(once, twice, f"{name}: 멱등하지 않다")


class EdgeCases(unittest.TestCase):
    def setUp(self):
        self.overlay = load_overlay([BASE_OVERLAY])

    def test_empty_file_gets_full_config(self):
        data = tomllib.loads(upsert("", self.overlay))
        self.assertEqual(data["model"], "gpt-5.5")
        self.assertEqual(data["features"]["plugins"], True)

    def test_existing_root_key_is_replaced_not_duplicated(self):
        out = upsert(read("root-keys-present.toml"), self.overlay)
        starts = [ln for ln in out.splitlines() if ln.strip().startswith("model =")]
        self.assertEqual(len(starts), 1, f"model 이 중복됐다: {starts}")
        self.assertIn('model = "gpt-5.5"', out)
        self.assertNotIn("gpt-4-old", out)

    def test_features_section_is_created_when_missing(self):
        before = read("no-features.toml")
        self.assertNotIn("[features]", before)
        out = upsert(before, self.overlay)
        self.assertIn("[features]", out)
        self.assertEqual(tomllib.loads(out)["features"]["goals"], True)

    def test_unowned_root_key_survives(self):
        # network_access 는 최상위 유효 키가 아니라 우리가 소유하지 않는다. 원문 보존돼야 한다.
        out = upsert(read("no-features.toml"), self.overlay)
        self.assertIn('network_access = "enabled"', out)

    def test_comments_and_blank_lines_survive(self):
        out = upsert(read("comments-and-blanks.toml"), self.overlay)
        for comment in ("# 맨 위 주석", "# 섹션 사이 주석", "# 섹션 안 주석", "# 파일 끝 주석"):
            self.assertIn(comment, out, f"주석이 사라졌다: {comment}")

    def test_multiline_array_is_not_corrupted(self):
        out = upsert(read("multiline-values.toml"), self.overlay)
        data = tomllib.loads(out)
        self.assertEqual(data["notify"], [
            "/Applications/Some App.app/Contents/MacOS/client",
            "turn-ended",
        ])
        self.assertEqual(data["sandbox_workspace_write"]["writable_roots"], ["/tmp", "/var/folders"])

    def test_key_inside_triple_quoted_string_is_not_touched(self):
        # 삼중따옴표 안의 'model = "속지 말 것"' 은 키가 아니므로 건드리면 안 된다
        out = upsert(read("multiline-values.toml"), self.overlay)
        self.assertIn('model = "속지 말 것"', out)
        self.assertIn("[features] 처럼 보이는 줄도 안전해야 한다", out)
        # TOML 은 여는 """ 바로 뒤의 개행을 잘라내므로 본문 3줄 = 개행 3개
        self.assertEqual(tomllib.loads(out)["banner"].count("\n"), 3)

    def test_app_generated_runtime_state_survives_intact(self):
        before = read("app-generated.toml")
        after = upsert(before, self.overlay)
        # 코덱스가 써 넣은 블록들
        self.assertEqual(before.count("trusted_hash"), after.count("trusted_hash"))
        self.assertEqual(before.count("trust_level"), after.count("trust_level"))
        for marker in ('[marketplaces.sisyphuslabs]', '[tui.model_availability_nux]',
                       '[agents.explorer]', '[mcp_servers.node_repl]',
                       '[shell_environment_policy.set]'):
            self.assertIn(marker, after, f"블록이 사라졌다: {marker}")
        # notify 는 머신 로컬 절대경로라 우리가 소유하지 않는다
        self.assertIn("SkyComputerUseClient", after)

    def test_scalars_in_other_sections_are_not_touched(self):
        # [plugins."omo@sisyphuslabs".mcp_servers.context7] 아래의 enabled 같은 키가
        # 루트 스칼라 교체에 휩쓸리면 안 된다
        before = read("app-generated.toml")
        after = upsert(before, self.overlay)
        self.assertEqual(before.count("enabled = true"), after.count("enabled = true"))
        self.assertEqual(before.count("enabled = false"), after.count("enabled = false"))


class OverlayFileItself(unittest.TestCase):
    """오버레이 파일이 "내가 의도한 구조"인지 본다.

    TOML 은 [table] 헤더 뒤의 맨 키를 그 테이블 소속으로 본다.
    default_permissions 를 [features] 아래에 잘못 두면 features.default_permissions 가 되고
    코덱스가 'expected a boolean' 으로 설정 로드에 실패한다. 문법은 멀쩡하므로
    tomllib 파싱만으로는 안 잡힌다.
    """

    def setUp(self):
        with open(BASE_OVERLAY, "rb") as fh:
            self.doc = tomllib.load(fh)

    def test_root_scalars_are_at_root(self):
        for key in list(EXPECTED) + ["default_permissions"]:
            self.assertIn(key, self.doc, f"{key} 가 루트에 없다 — 테이블 헤더 아래로 밀려났는지 확인")

    def test_features_holds_only_booleans(self):
        for key, value in self.doc.get("features", {}).items():
            self.assertIsInstance(value, bool, f"features.{key} 가 bool 이 아니다: {value!r}")

    def test_default_permissions_profile_exists(self):
        name = self.doc["default_permissions"]
        self.assertIn(name, self.doc.get("permissions", {}),
                      f"default_permissions 가 정의되지 않은 프로필 '{name}' 을 가리킨다")

    def test_filesystem_paths_follow_codex_rules(self):
        # codex-cli 0.144.6 실측: 경로는 절대경로 / "~/" / ":" 로 시작해야 하고,
        # glob 에는 "deny" 만 줄 수 있다("read" 는 정확한 경로나 "/**" 필요).
        fs = self.doc["permissions"][self.doc["default_permissions"]]["filesystem"]
        for path, access in fs.items():
            if isinstance(access, dict):
                continue  # ":workspace_roots" 같은 하위 테이블
            self.assertTrue(path.startswith(("/", "~/", ":")),
                            f"경로가 /, ~/, : 로 시작하지 않는다: {path}")
        for path, access in fs.get(":workspace_roots", {}).items():
            if "*" in path and access != "deny":
                self.assertTrue(path.endswith("/**"),
                                f'glob 에 "{access}" 를 주려면 /** 로 끝나야 한다: {path}')


class UnrestrictedOverlay(unittest.TestCase):
    def test_later_overlay_wins(self):
        overlay = load_overlay([BASE_OVERLAY, UNRESTRICTED_OVERLAY])
        data = tomllib.loads(upsert(read("app-generated.toml"), overlay))
        self.assertEqual(data["approval_policy"], "never")
        self.assertEqual(data["sandbox_mode"], "danger-full-access")
        self.assertEqual(data["model"], "gpt-5.5")  # 기본 오버레이의 나머지는 유지

    def test_base_overlay_alone_is_safe(self):
        overlay = load_overlay([BASE_OVERLAY])
        data = tomllib.loads(upsert(read("app-generated.toml"), overlay))
        self.assertEqual(data["approval_policy"], "on-request")
        self.assertEqual(data["sandbox_mode"], "workspace-write")


if __name__ == "__main__":
    unittest.main(verbosity=2)
