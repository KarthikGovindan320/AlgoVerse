"""
Stage 4 — Validation
Sanity-checks the finished SQLite database before copying it to Flutter assets.
All checks must pass before copying.

Usage:
    python validate.py
"""

import sqlite3
import os
import sys
import random

DB_PATH = os.path.join("output", "leetcode_problems.db")

EXPECTED_MIN_PROBLEMS = 2500
EXPECTED_MAX_PROBLEMS = 3500
MIN_TAG_COVERAGE = 0.80  # 80% of non-premium problems should have ≥1 tag


def run():
    if not os.path.exists(DB_PATH):
        print(f"[ERROR] DB not found at {DB_PATH}")
        sys.exit(1)

    conn = sqlite3.connect(DB_PATH)
    errors = []
    warnings = []

    print("=" * 60)
    print("AlgoVerse DB Validation")
    print("=" * 60)

    # ── Check 1: Problem count ────────────────────────────────────────────────
    total = conn.execute("SELECT COUNT(*) FROM problems").fetchone()[0]
    print(f"\n[1] Total problems: {total}")
    if total < EXPECTED_MIN_PROBLEMS:
        errors.append(f"Too few problems: {total} (expected ≥{EXPECTED_MIN_PROBLEMS})")
    elif total > EXPECTED_MAX_PROBLEMS:
        warnings.append(f"More problems than expected: {total} (expected ≤{EXPECTED_MAX_PROBLEMS})")
    else:
        print(f"    ✓ Count is within expected range [{EXPECTED_MIN_PROBLEMS}–{EXPECTED_MAX_PROBLEMS}]")

    # ── Check 2: No null titles or slugs ─────────────────────────────────────
    null_titles = conn.execute(
        "SELECT COUNT(*) FROM problems WHERE title IS NULL OR title = ''"
    ).fetchone()[0]
    null_slugs = conn.execute(
        "SELECT COUNT(*) FROM problems WHERE slug IS NULL OR slug = ''"
    ).fetchone()[0]
    print(f"\n[2] Null titles: {null_titles}, Null slugs: {null_slugs}")
    if null_titles > 0:
        errors.append(f"{null_titles} problems have null/empty titles")
    if null_slugs > 0:
        errors.append(f"{null_slugs} problems have null/empty slugs")
    if null_titles == 0 and null_slugs == 0:
        print("    ✓ All problems have titles and slugs")

    # ── Check 3: Unique slugs ─────────────────────────────────────────────────
    dup_slugs = conn.execute(
        "SELECT COUNT(*) FROM (SELECT slug, COUNT(*) c FROM problems GROUP BY slug HAVING c > 1)"
    ).fetchone()[0]
    print(f"\n[3] Duplicate slugs: {dup_slugs}")
    if dup_slugs > 0:
        errors.append(f"{dup_slugs} duplicate slug(s) found")
    else:
        print("    ✓ All slugs are unique")

    # ── Check 4: Tag coverage ─────────────────────────────────────────────────
    non_premium_total = conn.execute(
        "SELECT COUNT(*) FROM problems WHERE is_premium = 0 AND tagging_skipped = 0"
    ).fetchone()[0]
    tagged = conn.execute(
        """SELECT COUNT(DISTINCT p.id) FROM problems p
           INNER JOIN problem_tags pt ON p.id = pt.problem_id
           WHERE p.is_premium = 0"""
    ).fetchone()[0]
    coverage = tagged / non_premium_total if non_premium_total > 0 else 0
    print(f"\n[4] Tag coverage: {tagged}/{non_premium_total} non-premium "
          f"({coverage:.1%})")
    if coverage < MIN_TAG_COVERAGE:
        warnings.append(
            f"Tag coverage {coverage:.1%} is below minimum {MIN_TAG_COVERAGE:.0%} — "
            "run tagger.py to completion"
        )
    else:
        print(f"    ✓ Coverage meets minimum {MIN_TAG_COVERAGE:.0%}")

    # ── Check 5: Concept graph has edges ─────────────────────────────────────
    edge_count = conn.execute(
        "SELECT COUNT(*) FROM concept_prerequisites"
    ).fetchone()[0]
    tag_count = conn.execute("SELECT COUNT(*) FROM tags").fetchone()[0]
    print(f"\n[5] Concept graph: {tag_count} tags, {edge_count} prerequisite edges")
    if edge_count == 0 and tag_count > 0:
        warnings.append("No prerequisite edges found — run graph_builder.py")
    else:
        print(f"    ✓ Graph has edges")

    # ── Check 6: No cycles ────────────────────────────────────────────────────
    from collections import defaultdict, deque
    edges = conn.execute(
        "SELECT tag_id, requires_tag_id FROM concept_prerequisites"
    ).fetchall()
    adj = defaultdict(set)
    in_degree = defaultdict(int)
    all_nodes = set()
    for t, r in edges:
        adj[t].add(r)
        in_degree[r] += 1
        all_nodes.update([t, r])
    for n in all_nodes:
        in_degree.setdefault(n, 0)
    queue = deque([n for n in all_nodes if in_degree[n] == 0])
    visited = 0
    while queue:
        node = queue.popleft()
        visited += 1
        for nb in adj[node]:
            in_degree[nb] -= 1
            if in_degree[nb] == 0:
                queue.append(nb)
    has_cycle = visited < len(all_nodes)
    print(f"\n[6] Cycle detection: {'CYCLE DETECTED ⚠️' if has_cycle else '✓ No cycles'}")
    if has_cycle:
        errors.append("Concept graph contains cycles — run graph_builder.py to fix")

    # ── Check 7: Spot-check 20 random problems ────────────────────────────────
    print(f"\n[7] Spot-check (20 random non-premium, tagged problems):")
    samples = conn.execute(
        """SELECT p.id, p.slug, p.title, p.difficulty,
                  p.acceptance_rate, p.insight_summary
           FROM problems p
           INNER JOIN problem_tags pt ON p.id = pt.problem_id
           WHERE p.is_premium = 0
           GROUP BY p.id
           ORDER BY RANDOM()
           LIMIT 20"""
    ).fetchall()

    for row in samples:
        pid, slug, title, diff, ar, insight = row
        tags = conn.execute(
            "SELECT t.name FROM tags t INNER JOIN problem_tags pt ON t.id = pt.tag_id WHERE pt.problem_id = ?",
            (pid,),
        ).fetchall()
        tag_names = [t[0] for t in tags]
        ar_str = f"{ar:.1%}" if ar else "N/A"
        has_insight = "✓" if insight else "✗"
        print(f"    [{pid:4d}] {title[:40]:<40} {diff:<7} AR:{ar_str:<6} insight:{has_insight} tags:{tag_names[:3]}")

    # ── Check 8: DB version ───────────────────────────────────────────────────
    db_version = conn.execute(
        "SELECT value FROM meta WHERE key = 'db_version'"
    ).fetchone()
    print(f"\n[8] DB version: {db_version[0] if db_version else 'NOT SET'}")
    if not db_version:
        errors.append("DB version not set in meta table")

    conn.close()

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "=" * 60)
    if errors:
        print(f"FAILED — {len(errors)} error(s):")
        for e in errors:
            print(f"  ✗ {e}")
    if warnings:
        print(f"WARNINGS — {len(warnings)}:")
        for w in warnings:
            print(f"  ⚠ {w}")
    if not errors and not warnings:
        print("ALL CHECKS PASSED ✓")
        print("\nYou can now copy the DB to Flutter assets:")
        print("  copy pipeline\\output\\leetcode_problems.db assets\\data\\leetcode_problems.db")
    elif not errors:
        print("\nNo blocking errors. DB is usable (review warnings above).")
    else:
        print("\nFix errors before using this DB in the app.")
        sys.exit(1)
    print("=" * 60)


if __name__ == "__main__":
    run()
