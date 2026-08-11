#!/usr/bin/env python3
# SPDX-FileCopyrightText: Copyright The Zephyr Project Contributors
# SPDX-License-Identifier: Apache-2.0
"""
Read a twister.json file and write a summary markdown report alongside it.

Usage:
    python3 summarize_twister.py <twister.json>
    python3 summarize_twister.py <twister.json> --output <report.md>
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Summarize twister.json results as Markdown.",
    )
    parser.add_argument("json_file", type=Path,
                        help="Path to twister.json")
    parser.add_argument("--output", "-o", type=Path, default=None,
                        help="Output path (default: <json_dir>/summary.md)")
    return parser.parse_args()


def category_of(path: str) -> str:
    """Return the first two path components, e.g. 'tests/kernel'."""
    parts = Path(path).parts
    if len(parts) >= 2:
        return str(Path(parts[0]) / parts[1])
    return parts[0] if parts else "unknown"


def fmt_time(seconds: float) -> str:
    if seconds < 60.0:
        return f"{seconds:.1f} s"
    minutes = seconds / 60.0
    if minutes < 60.0:
        return f"{minutes:.1f} min"
    return f"{seconds / 3600.0:.1f} h"


def build_time_stats(suites: list[dict]) -> dict[str, float]:
    times = [float(s.get("build_time", 0.0)) for s in suites if s.get("build_time")]
    if not times:
        return {}
    return {
        "min": min(times),
        "max": max(times),
        "avg": sum(times) / len(times),
        "total": sum(times),
    }


def suite_result(suite: dict, build_only: bool) -> str:
    status = (suite.get("status") or "").lower()
    if build_only:
        return "pass" if status == "not run" else "fail"
    if status == "passed":
        return "pass"
    if status == "failed":
        return "fail"
    if status == "error":
        return "error"
    if status == "skipped":
        return "skip"
    return "not_run"


def generate_report(data: dict) -> str:
    env = data.get("environment", {})
    opts = env.get("options", {})
    suites: list[dict] = data.get("testsuites", [])

    build_only: bool = bool(opts.get("build_only", False))
    platform: str = ", ".join(opts.get("platform", ["unknown"]))
    zephyr_ver: str = env.get("zephyr_version", "unknown")
    toolchain: str = env.get("toolchain", "unknown")
    commit_date: str = (env.get("commit_date") or "")[:10]
    run_date: str = (env.get("run_date") or "")[:10]
    mode_str: str = "Build-only (`--build-only`)" if build_only else "Flash + run"

    # ── Suite-level counts ────────────────────────────────────────────────────
    total_suites = len(suites)
    suite_counts: dict[str, int] = defaultdict(int)
    for s in suites:
        suite_counts[suite_result(s, build_only)] += 1

    # ── Test-case counts ──────────────────────────────────────────────────────
    total_tcs = sum(len(s.get("testcases", [])) for s in suites)

    # ── Category breakdown ────────────────────────────────────────────────────
    samples_cats: dict[str, int] = defaultdict(int)
    tests_cats: dict[str, int] = defaultdict(int)
    for s in suites:
        path = s.get("path", "")
        cat = category_of(path)
        if path.startswith("samples"):
            samples_cats[cat] += 1
        else:
            tests_cats[cat] += 1

    total_samples = sum(samples_cats.values())
    total_tests = sum(tests_cats.values())

    # ── Build time ────────────────────────────────────────────────────────────
    bt = build_time_stats(suites)

    # ── Failed / errored suites ───────────────────────────────────────────────
    failures = [
        s for s in suites
        if suite_result(s, build_only) not in ("pass", "not_run")
    ]

    # ── Render markdown ───────────────────────────────────────────────────────
    lines: list[str] = []

    def row(*cells: str) -> str:
        return "| " + " | ".join(str(c) for c in cells) + " |"

    def sep(n: int) -> str:
        return "| " + " | ".join(["---"] * n) + " |"

    # Header
    title_core = platform.split("/")[-1] if "/" in platform else platform
    lines.append(f"# Twister Summary — PSE84 {title_core}\n")

    lines.append(row("Field", "Value"))
    lines.append(sep(2))
    lines.append(row("**Board**", f"`{platform}`"))
    lines.append(row("**Zephyr version**", f"`{zephyr_ver}`"))
    lines.append(row("**Toolchain**", f"`{toolchain}`"))
    lines.append(row("**Commit date**", commit_date))
    lines.append(row("**Run date**", run_date))
    lines.append(row("**Mode**", mode_str))
    lines.append("")

    # Overall results
    lines.append("## Overall Results\n")
    lines.append(row("Metric", "Count"))
    lines.append(sep(2))
    lines.append(row("Total test suites", f"**{total_suites}**"))

    if build_only:
        n_pass = suite_counts.get("pass", 0)
        n_fail = suite_counts.get("fail", 0)
        lines.append(row("Successfully built", f"**{n_pass}**"))
        if n_fail:
            lines.append(row("Build failures", f"**{n_fail}**"))
    else:
        for label, key in (
            ("Passed",   "pass"),
            ("Failed",   "fail"),
            ("Errors",   "error"),
            ("Skipped",  "skip"),
            ("Not run",  "not_run"),
        ):
            count = suite_counts.get(key, 0)
            if count or key in ("pass", "fail"):
                lines.append(row(f"**{label}**", f"**{count}**"))

    # Format total test cases with thousands separator
    tc_str = f"{total_tcs:,}".replace(",", "\u202f")
    lines.append(row("Total test cases", f"**{tc_str}**"))
    lines.append(row("Samples", str(total_samples)))
    lines.append(row("Tests", str(total_tests)))
    lines.append("")

    # Narrative summary line
    if build_only and suite_counts.get("fail", 0) == 0:
        lines.append(
            f"All {total_suites} suites compiled successfully. No build failures. "
            "Test cases are marked\n`not run` — expected for a build-only run "
            "(no hardware execution).\n"
        )
    elif not build_only and suite_counts.get("pass", 0) == total_suites:
        lines.append(f"All {total_suites} suites passed.\n")

    if bt:
        lines.append(
            f"Build time: min {fmt_time(bt['min'])} · "
            f"max {fmt_time(bt['max'])} · "
            f"avg {fmt_time(bt['avg'])} · "
            f"total ≈ {fmt_time(bt['total'])} (parallel)\n"
        )

    lines.append("---\n")

    # Samples table
    if samples_cats:
        lines.append(f"## Samples ({total_samples} suites)\n")
        lines.append(row("Category", "Suites"))
        lines.append(sep(2))
        for cat, count in sorted(samples_cats.items(), key=lambda x: (-x[1], x[0])):
            lines.append(row(f"`{cat}`", str(count)))
        lines.append("")
        lines.append("---\n")

    # Tests table
    if tests_cats:
        lines.append(f"## Tests ({total_tests} suites)\n")
        lines.append(row("Category", "Suites"))
        lines.append(sep(2))
        for cat, count in sorted(tests_cats.items(), key=lambda x: (-x[1], x[0])):
            lines.append(row(f"`{cat}`", str(count)))
        lines.append("")
        lines.append("---\n")

    # Failures section (only when there are failures)
    if failures:
        lines.append(f"## Failures / Errors ({len(failures)} suites)\n")
        lines.append(row("Suite", "Status", "Reason"))
        lines.append(sep(3))
        for s in failures[:100]:
            name = s.get("name", "?")
            status = s.get("status", "?")
            reason = (s.get("reason") or "").replace("|", "\\|")
            lines.append(row(f"`{name}`", status, reason))
        if len(failures) > 100:
            lines.append(f"\n_... and {len(failures) - 100} more._\n")
        lines.append("")
        lines.append("---\n")

    # Files table
    lines.append("## Files\n")
    lines.append(row("File", "Description"))
    lines.append(sep(2))
    lines.append(row("`twister.json`", f"Full machine-readable results (all {total_suites} suites)"))
    lines.append(row("`twister.xml`", "JUnit XML"))
    lines.append(row("`twister_report.xml`", "Twister-format XML report"))
    lines.append(row("`twister_suite_report.xml`", "Suite-level XML report"))
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    args = parse_args()

    json_path: Path = args.json_file.resolve()
    if not json_path.is_file():
        print(f"ERROR: file not found: {json_path}", file=sys.stderr)
        sys.exit(1)

    output_path: Path = (
        args.output.resolve() if args.output
        else json_path.parent / "summary.md"
    )

    with json_path.open(encoding="utf-8") as fh:
        data = json.load(fh)

    report = generate_report(data)

    with output_path.open("w", encoding="utf-8") as fh:
        fh.write(report)

    print(f"Summary written to {output_path}")


if __name__ == "__main__":
    main()
