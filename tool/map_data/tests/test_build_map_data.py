from __future__ import annotations

import gzip
import io
import json
import socket
import subprocess
import sys
import tempfile
import unittest
import urllib.request
from collections.abc import Iterator
from contextlib import redirect_stdout
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_map_data as builder  # noqa: E402

SOURCE_SHA = "a" * 64
GENERATED_AT = "2026-10-20T12:00:00+0000"
HEIGHT_COUNTS = {
    "buildingsWithPositiveNumericHeight": 1,
    "buildingsWithLevelsOnly": 1,
    "buildingsWithRejectedHeight": 0,
    "buildingsWithUnsupportedHeight": 0,
}
POINTS = [[-22.2, -49.8], [-22.2, -49.79], [-22.19, -49.79], [-22.2, -49.8]]


def write_gzip_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(gzip.compress(json.dumps(value, separators=(",", ":")).encode(), mtime=0))


def dataset_manifest(root: Path, generated_at: str, with_height_counts: bool) -> dict[str, object]:
    cells = root / "cells"
    counts: dict[str, int] = {
        "roadsInCells": 1,
        "rail": 0,
        "waterlines": 0,
        "areas": 0,
        "pois": 0,
        "labels": 0,
        "buildings": 2,
        # Existing mixed per-source-way count remains unchanged.
        "buildingsWithHeightTag": 2,
    }
    if with_height_counts:
        counts.update(HEIGHT_COUNTS)
    return {
        "version": 2,
        "bbox": [-50.04, -22.31, -49.59, -22.13],
        "tileBounds": {"west": -50.04, "south": -22.31, "east": -49.59, "north": -22.13},
        "cellSize": 0.05,
        "cols": 9,
        "rows": 4,
        "generatedAt": generated_at,
        "source": "OpenStreetMap local extract",
        "sourceSha256": SOURCE_SHA,
        "attribution": "© OpenStreetMap contributors",
        "counts": counts,
        "l0Bytes": sum(path.stat().st_size for path in cells.glob("l0_*.json.gz")),
        "l1Bytes": sum(path.stat().st_size for path in cells.glob("l1_*.json.gz")),
    }


def write_dataset(root: Path, *, staged: bool = False) -> None:
    l0 = {"roads": [{"c": 1, "p": [1, 2]}], "areas": []}
    accepted = {"p": [coordinate for point in POINTS for coordinate in point], "b": [-22.2, -49.8, -22.19, -49.79]}
    levels_only = {"p": [coordinate for point in POINTS for coordinate in point], "b": [-22.2, -49.8, -22.19, -49.79]}
    if staged:
        accepted["height"] = 3.5
    write_gzip_json(root / "cells/l0_0_0.json.gz", l0)
    write_gzip_json(root / "cells/l1_0_0.json.gz", {"bld": [accepted, levels_only]})
    manifest = dataset_manifest(root, GENERATED_AT if staged else "2026-10-19T11:27:17-0300", staged)
    (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")


class HeightParserTest(unittest.TestCase):
    def test_accepts_only_finite_positive_ascii_decimal_metres(self) -> None:
        for value, expected in (("3", 3.0), ("003.50", 3.5), ("1.25", 1.25)):
            parsed, status = builder.parse_height(value)
            self.assertEqual((parsed, status), (expected, "accepted"))
        parsed, status = builder.parse_height("9" * 308)
        self.assertEqual(status, "accepted")
        self.assertGreater(parsed, 0)
        parsed, status = builder.parse_height("9" * 400)
        self.assertIsNone(parsed)
        self.assertEqual(status, "nonfinite")
        parsed, status = builder.parse_height("1" + "0" * 307)
        self.assertEqual((parsed, status), (1e307, "accepted"))

    def test_nonpositive_numeric_and_unsupported_formats_are_rejected(self) -> None:
        for value in ("0", "0.0", "-0", "-1", "-1.25"):
            parsed, status = builder.parse_height(value)
            self.assertIsNone(parsed)
            self.assertEqual(status, "nonpositive")
        for value in ("10 m", "+3", "3,5", "1e2", ".5", "5.", " 3", "٣"):
            parsed, status = builder.parse_height(value)
            self.assertIsNone(parsed)
            self.assertEqual(status, "unsupported")
        for value in (None, ""):
            self.assertEqual(builder.parse_height(value), (None, "missing"))
        self.assertEqual(builder.parse_height("0." + "0" * 400 + "1"), (None, "underflow"))

    def test_bad_grammar_and_levels_only_records_remain_flat(self) -> None:
        for value in ("10 m", "+3", "3,5", "1e2", ".5", "5."):
            parsed, _status = builder.parse_height(value)
            record = builder.building_record(POINTS, parsed)
            self.assertNotIn("height", record)
        builder.reset_data()
        self.assertIsNone(builder.account_building_height_tags({"building:levels": "2"}))
        record = builder.building_record(POINTS)
        self.assertNotIn("height", record)
        self.assertEqual(builder.height_stats["levels_only"], 1)

    def test_height_counters_are_per_source_way_and_legacy_counter_stays_mixed(self) -> None:
        builder.reset_data()
        self.assertEqual(builder.account_building_height_tags({"height": "3", "building:levels": "1"}), 3.0)
        self.assertIsNone(builder.account_building_height_tags({"building:levels": "2"}))
        self.assertIsNone(builder.account_building_height_tags({"height": "3 m", "building:levels": "2"}))
        self.assertIsNone(builder.account_building_height_tags({"height": "-1"}))
        self.assertEqual(builder.heights_tagged, 4)
        self.assertEqual(builder.height_stats["accepted"], 1)
        self.assertEqual(builder.height_stats["levels_only"], 1)
        self.assertEqual(builder.height_stats["unsupported"], 1)
        self.assertEqual(builder.height_stats["nonpositive"], 1)
        self.assertEqual(builder.height_manifest_counts(), {
            "buildingsWithPositiveNumericHeight": 1,
            "buildingsWithLevelsOnly": 1,
            "buildingsWithRejectedHeight": 1,
            "buildingsWithUnsupportedHeight": 1,
        })


class SemanticGateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.baseline = self.root / "baseline"
        self.stage = self.root / "stage"
        write_dataset(self.baseline)
        write_dataset(self.stage, staged=True)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def compare(self) -> dict[str, object]:
        return builder.compare_outputs(
            self.baseline, self.stage, GENERATED_AT, SOURCE_SHA, HEIGHT_COUNTS
        )

    def test_clean_height_only_delta_passes_and_summarizes(self) -> None:
        summary = self.compare()
        self.assertEqual(summary["cellFilesCompared"], 2)
        self.assertEqual(summary["heightAdditions"], 1)
        self.assertIn("generatedAt", summary["approvedManifestChanges"])
        self.assertIn("l1Bytes", summary["approvedManifestChanges"])
        self.assertIn("counts.buildingsWithPositiveNumericHeight", summary["approvedManifestChanges"])

    def test_non_height_cell_change_rejects(self) -> None:
        write_gzip_json(self.stage / "cells/l0_0_0.json.gz", {"roads": [{"c": 2, "p": [1, 2]}], "areas": []})
        with self.assertRaisesRegex(builder.SemanticComparisonError, "JSON value changed"):
            self.compare()

    def test_cell_membership_change_rejects(self) -> None:
        write_gzip_json(self.stage / "cells/l1_1_0.json.gz", {"bld": []})
        with self.assertRaisesRegex(builder.SemanticComparisonError, "cell path membership changed"):
            self.compare()

    def test_building_geometry_and_record_membership_changes_reject(self) -> None:
        path = self.stage / "cells/l1_0_0.json.gz"
        staged = json.loads(gzip.decompress(path.read_bytes()))
        staged["bld"][0]["p"][0] += 0.001
        write_gzip_json(path, staged)
        with self.assertRaisesRegex(builder.SemanticComparisonError, "JSON value changed"):
            self.compare()

        write_dataset(self.stage, staged=True)
        staged = json.loads(gzip.decompress(path.read_bytes()))
        staged["bld"].append(dict(staged["bld"][1]))
        write_gzip_json(path, staged)
        with self.assertRaisesRegex(builder.SemanticComparisonError, "JSON list length changed"):
            self.compare()

    def test_malformed_staged_cell_fails_closed(self) -> None:
        (self.stage / "cells/l0_0_0.json.gz").write_bytes(b"not a gzip file")
        with self.assertRaisesRegex(builder.SemanticComparisonError, "invalid cell JSON"):
            self.compare()

    def test_non_height_manifest_count_change_rejects(self) -> None:
        manifest = json.loads((self.stage / "manifest.json").read_text(encoding="utf-8"))
        manifest["counts"]["roadsInCells"] += 1
        (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(builder.SemanticComparisonError, "non-height manifest count changed"):
            self.compare()

    def test_every_non_height_manifest_field_and_count_is_protected(self) -> None:
        changed_fields = {
            "version": 3,
            "bbox": [0, 0, 1, 1],
            "tileBounds": {"west": 0},
            "cellSize": 0.06,
            "cols": 10,
            "rows": 5,
            "source": "changed source",
            "sourceSha256": "b" * 64,
            "attribution": "changed attribution",
        }
        for field, changed_value in changed_fields.items():
            with self.subTest(manifest_field=field):
                write_dataset(self.stage, staged=True)
                manifest = json.loads((self.stage / "manifest.json").read_text(encoding="utf-8"))
                manifest[field] = changed_value
                (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaises(builder.SemanticComparisonError):
                    self.compare()

        for field in dataset_manifest(self.stage, GENERATED_AT, with_height_counts=True)["counts"]:
            if field in HEIGHT_COUNTS:
                continue
            with self.subTest(manifest_count=field):
                write_dataset(self.stage, staged=True)
                manifest = json.loads((self.stage / "manifest.json").read_text(encoding="utf-8"))
                manifest["counts"][field] += 1
                (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaises(builder.SemanticComparisonError):
                    self.compare()

    def test_l0_bytes_must_be_unchanged_even_when_stage_total_is_correct(self) -> None:
        path = self.stage / "cells/l0_0_0.json.gz"
        value = {"roads": [{"c": 1, "p": [1, 2]}], "areas": []}
        path.write_bytes(gzip.compress(json.dumps(value, separators=(",", ":")).encode(), compresslevel=0, mtime=0))
        manifest = json.loads((self.stage / "manifest.json").read_text(encoding="utf-8"))
        manifest["l0Bytes"] = sum(item.stat().st_size for item in (self.stage / "cells").glob("l0_*.json.gz"))
        (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(builder.SemanticComparisonError, "non-height manifest field changed: l0Bytes"):
            self.compare()

    def test_l0_bytes_must_match_actual_staged_total(self) -> None:
        manifest = json.loads((self.stage / "manifest.json").read_text(encoding="utf-8"))
        manifest["l0Bytes"] += 1
        (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(builder.SemanticComparisonError, "staged l0Bytes does not match staged L0 files"):
            self.compare()

    def test_missing_l0_bytes_fails_closed(self) -> None:
        for root in (self.baseline, self.stage):
            manifest_path = root / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            del manifest["l0Bytes"]
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(builder.SemanticComparisonError, "staged l0Bytes does not match staged L0 files"):
            self.compare()

    def test_invalid_height_and_unapproved_manifest_metadata_reject(self) -> None:
        write_gzip_json(self.stage / "cells/l1_0_0.json.gz", {
            "bld": [
                {"p": [coordinate for point in POINTS for coordinate in point], "b": [-22.2, -49.8, -22.19, -49.79], "height": 0},
                {"p": [coordinate for point in POINTS for coordinate in point], "b": [-22.2, -49.8, -22.19, -49.79]},
            ],
        })
        with self.assertRaisesRegex(builder.SemanticComparisonError, "invalid additive height"):
            self.compare()

        write_dataset(self.stage, staged=True)
        manifest = json.loads((self.stage / "manifest.json").read_text(encoding="utf-8"))
        manifest["source"] = "not the source metadata"
        (self.stage / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        with self.assertRaisesRegex(builder.SemanticComparisonError, "non-allowlisted manifest field changed"):
            self.compare()

    def test_gate_promotes_only_after_clean_compare(self) -> None:
        summary = builder.promote_stage(
            self.baseline, self.stage, GENERATED_AT, SOURCE_SHA, SOURCE_SHA, HEIGHT_COUNTS
        )
        with gzip.open(self.baseline / "cells/l1_0_0.json.gz", "rt", encoding="utf-8") as source:
            promoted = json.load(source)
        self.assertEqual(promoted["bld"][0]["height"], 3.5)
        self.assertEqual(summary["heightAdditions"], 1)
        self.assertEqual(json.loads((self.baseline / "manifest.json").read_text())["counts"]["buildingsWithHeightTag"], 2)

    def test_failed_compare_does_not_write_baseline(self) -> None:
        before = {path: path.read_bytes() for path in self.baseline.rglob("*") if path.is_file()}
        write_gzip_json(self.stage / "cells/l0_0_0.json.gz", {"roads": [{"c": 2, "p": [1, 2]}], "areas": []})
        with self.assertRaises(builder.SemanticComparisonError):
            builder.promote_stage(
                self.baseline, self.stage, GENERATED_AT, SOURCE_SHA, SOURCE_SHA, HEIGHT_COUNTS
            )
        after = {path: path.read_bytes() for path in before}
        self.assertEqual(after, before)


class StageSafetyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.pbf = self.root / "source.osm.pbf"
        self.pbf.write_bytes(b"local fixture only")
        self.stage = self.root / "stage"

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_absent_source_fails_before_processing_or_writes(self) -> None:
        missing = self.root / "missing.osm.pbf"
        with patch.object(builder, "process") as process, patch.object(builder, "write_outputs") as writer:
            with self.assertRaisesRegex(builder.GenerationError, "local PBF is absent"):
                builder.generate_staged(missing, self.stage)
        process.assert_not_called()
        writer.assert_not_called()
        self.assertFalse(self.stage.exists())

    def test_source_hash_mismatch_fails_before_stage_writes_or_promotion(self) -> None:
        with patch.object(builder, "process"), \
             patch.object(builder, "sha256", side_effect=["1" * 64, "2" * 64]), \
             patch.object(builder, "write_outputs") as writer:
            with self.assertRaisesRegex(builder.GenerationError, "no staged files written"):
                builder.generate_staged(self.pbf, self.stage)
        writer.assert_not_called()
        self.assertFalse(self.stage.exists())

    def test_source_must_remain_unchanged_through_output_generation(self) -> None:
        target = self.root / "baseline"
        write_dataset(target)
        baseline_bytes = {path: path.read_bytes() for path in target.rglob("*") if path.is_file()}

        def mutate_source(_source_sha256: str, generated_at: str) -> None:
            (self.stage / "manifest.json").write_text(
                json.dumps({"sourceSha256": builder.sha256(self.pbf), "generatedAt": generated_at}),
                encoding="utf-8",
            )
            self.pbf.write_bytes(b"modified during generation")

        with patch.object(builder, "process"), patch.object(builder, "write_outputs", side_effect=mutate_source):
            with self.assertRaisesRegex(builder.GenerationError, "changed during generation"):
                builder.generate_staged(self.pbf, self.stage, target)
        self.assertEqual({path: path.read_bytes() for path in baseline_bytes}, baseline_bytes)

    def test_mismatched_stage_manifest_source_is_not_promoted(self) -> None:
        target = self.root / "baseline"
        write_dataset(target)
        baseline_bytes = {path: path.read_bytes() for path in target.rglob("*") if path.is_file()}

        def write_bad_manifest(_source_sha: str, generated_at: str) -> None:
            (self.stage / "manifest.json").write_text(
                json.dumps({"sourceSha256": "0" * 64, "generatedAt": generated_at}),
                encoding="utf-8",
            )

        with patch.object(builder, "process"), patch.object(builder, "write_outputs", side_effect=write_bad_manifest):
            with self.assertRaisesRegex(builder.GenerationError, "staged manifest sourceSha256"):
                builder.generate_staged(self.pbf, self.stage, target)
        self.assertEqual({path: path.read_bytes() for path in baseline_bytes}, baseline_bytes)

    def test_production_path_cannot_be_used_as_stage(self) -> None:
        with patch.object(builder, "process") as process:
            with self.assertRaisesRegex(builder.GenerationError, "stage path overlaps protected output"):
                builder.generate_staged(self.pbf, builder.ASSETS_ROOT)
        process.assert_not_called()
        self.assertTrue(self.pbf.is_file())

    def test_legacy_out_option_uses_temporary_stage_and_gated_promotion(self) -> None:
        target = self.root / "existing-output"
        result = {
            "sourceSha256Before": SOURCE_SHA,
            "sourceSha256After": SOURCE_SHA,
            "semanticDelta": {},
            "heightCounts": HEIGHT_COUNTS,
        }
        stdout = io.StringIO()
        with patch.object(builder, "generate_staged", return_value=result) as generate, redirect_stdout(stdout):
            self.assertEqual(builder.main(["--pbf", str(self.pbf), "--out", str(target)]), 0)
        args = generate.call_args.args
        self.assertEqual(args[0], self.pbf)
        self.assertTrue(args[1].name.startswith("fogo-map-stage-"))
        self.assertEqual(args[2], target)
        self.assertIn("PBF SHA-256 before", stdout.getvalue())

    def test_local_generation_has_no_download_or_process_spawn_path(self) -> None:
        def write_fixture_manifest(source_sha: str, generated_at: str) -> None:
            (self.stage / "manifest.json").write_text(
                json.dumps({"sourceSha256": source_sha, "generatedAt": generated_at}),
                encoding="utf-8",
            )

        with patch.object(builder, "process"), \
             patch.object(builder, "write_outputs", side_effect=write_fixture_manifest), \
             patch.object(urllib.request, "urlopen", side_effect=AssertionError("network forbidden")) as urlopen, \
             patch.object(socket, "create_connection", side_effect=AssertionError("network forbidden")) as connect, \
             patch.object(subprocess, "run", side_effect=AssertionError("process spawn forbidden")) as run:
            result = builder.generate_staged(self.pbf, self.stage)
        urlopen.assert_not_called()
        connect.assert_not_called()
        run.assert_not_called()
        self.assertEqual(result["sourceSha256Before"], result["sourceSha256After"])
        self.assertTrue((self.stage / "manifest.json").is_file())


class SourceHeightPersistenceTest(unittest.TestCase):
    def test_process_persists_only_accepted_height_from_source_way(self) -> None:
        class FakeProcessor:
            def with_locations(self) -> "FakeProcessor":
                return self

            def with_areas(self) -> "FakeProcessor":
                return self

            def __iter__(self) -> Iterator[object]:
                return iter(ways)

        def make_way(tags: dict[str, str], points: list[list[float]]) -> SimpleNamespace:
            return SimpleNamespace(
                tags=[SimpleNamespace(k=key, v=value) for key, value in tags.items()],
                nodes=[SimpleNamespace(lat=lat, lon=lon) for lat, lon in points],
                is_way=lambda: True,
                is_closed=lambda: True,
            )

        variants = [
            ({"building": "yes", "height": "3.50"}, POINTS),
            (
                {"building": "yes", "height": "3 m", "building:levels": "2"},
                [[lat, lon + 0.001] for lat, lon in POINTS],
            ),
            (
                {"building": "yes", "building:levels": "2"},
                [[lat + 0.001, lon] for lat, lon in POINTS],
            ),
        ]
        ways = [make_way(tags, points) for tags, points in variants]
        builder.reset_data()
        self.addCleanup(builder.reset_data)
        with patch.object(builder, "args", SimpleNamespace(pbf="local-fixture"), create=True), \
             patch.object(builder.osmium, "FileProcessor", return_value=FakeProcessor()):
            builder.process()

        records = [record for cell in builder.L1.values() for record in cell["bld"]]
        records_by_points = {tuple(record["p"]): record for record in records}
        accepted_points = tuple(coordinate for point in POINTS for coordinate in point)
        unsupported_points = tuple(builder.r5(coordinate) for point in variants[1][1] for coordinate in point)
        levels_only_points = tuple(builder.r5(coordinate) for point in variants[2][1] for coordinate in point)
        self.assertEqual(records_by_points[accepted_points]["height"], 3.5)
        self.assertNotIn("height", records_by_points[unsupported_points])
        self.assertNotIn("height", records_by_points[levels_only_points])
        self.assertEqual(builder.building_count, 3)
        self.assertEqual(builder.heights_tagged, 3)
        self.assertEqual(builder.height_manifest_counts(), {
            "buildingsWithPositiveNumericHeight": 1,
            "buildingsWithLevelsOnly": 1,
            "buildingsWithRejectedHeight": 0,
            "buildingsWithUnsupportedHeight": 1,
        })


if __name__ == "__main__":
    unittest.main()
