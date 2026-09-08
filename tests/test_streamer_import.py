"""Offline importer contracts; no Twitch credentials or network required."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("import_streamers", Path(__file__).parents[1] / "tools/import_streamers.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


def record(login, game="Dota 2"):
    return {"user_login": login, "user_name": login, "viewer_count": 1234, "game_name": game}


class ImporterTests(unittest.TestCase):
    def test_pages_and_duplicates(self):
        queries = []
        pages = iter([
            {"data": [record("First")], "pagination": {"cursor": "next"}},
            {"data": [record("first"), record("second", "Unknown")], "pagination": {}},
        ])
        def fetch(query):
            queries.append(query)
            return next(pages)
        profiles = importer.collect(fetch)["profiles"]
        self.assertEqual([p["id"] for p in profiles], ["first", "second"])
        self.assertEqual(queries[1], {"first": 100, "language": "ru", "after": "next"})
        self.assertEqual(profiles[0]["interests"], ["dota_2"])
        self.assertEqual(profiles[1]["interests"], [])
        self.assertTrue(all(not p["is_placeholder"] and p["source"].startswith("https://") for p in profiles))

    def test_repeated_cursor_stops(self):
        calls = []
        def fetch(query):
            calls.append(query)
            return {"data": [record("same")], "pagination": {"cursor": "loop"}}
        self.assertEqual(len(importer.collect(fetch)["profiles"]), 1)
        self.assertEqual(len(calls), 2)

    def test_limit_and_empty(self):
        self.assertEqual(len(importer.collect(lambda _: {"data": [record(str(i)) for i in range(20)]}, 5)["profiles"]), 5)
        self.assertEqual(importer.collect(lambda _: {"data": [], "pagination": {"cursor": "unused"}}), {"profiles": []})


if __name__ == "__main__":
    unittest.main()
