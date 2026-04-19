"""
Stage 2 — Gemini Concept Tagger
Reads untagged problems from the SQLite DB, calls Gemini to generate
granular concept tags, and writes results back.

Checkpoint-safe: already-tagged problems are skipped automatically.
Rate-limited to ~55 requests/minute (Gemini free tier).

Usage (with venv activated):
    python tagger.py              # full run
    python tagger.py --test 5    # test on first 5 problems only
"""

import sqlite3
import json
import os
import re
import sys
import time
import argparse
import asyncio
from typing import Optional

from dotenv import load_dotenv

load_dotenv()

DB_PATH = os.path.join("output", "leetcode_problems.db")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
MODEL = "gemini-2.5-flash"

# Rate limiting: 55 requests/minute max
REQUESTS_PER_MINUTE = 55
DELAY_BETWEEN_REQUESTS = 60.0 / REQUESTS_PER_MINUTE  # ~1.09 seconds
MAX_CONCURRENT = 5
CHECKPOINT_EVERY = 50

SYSTEM_PROMPT = """You are a DSA expert and educator. Given a LeetCode problem statement, identify every algorithmic concept and data structure needed to solve it. Tag ALL valid approaches — if multiple strategies can solve this problem, include concepts for each approach.

Return ONLY valid JSON. No preamble, no explanation outside the JSON.

Be GRANULAR in your tagging:
- Not "Graph" → "Dijkstra's Algorithm", "Union-Find / Disjoint Set", "Topological Sort"
- Not "DP" → "DP with Memoization", "DP on Intervals", "Bitmask DP"
- Not "Sliding Window" → "Sliding Window (Variable Size)", "Sliding Window (Fixed Size)"
- Not "Tree" → "Binary Tree DFS", "Binary Tree BFS", "Binary Search Tree"

Prerequisites should be concepts the user MUST understand first — be logical and specific."""

USER_PROMPT_TEMPLATE = """Problem Title: {title}
Difficulty: {difficulty}
LeetCode's own tags (use these as primary signal when no statement is available): {lc_tags}

Problem Statement:
{statement}

Return this exact JSON structure:
{{
  "primary_concept": "the most canonical/common approach concept name",
  "all_tags": ["every relevant concept — be granular, at least 2-5 tags"],
  "alternative_approaches": ["other valid concepts/strategies, or [] if none"],
  "prerequisites": ["concepts the user must already know to attempt this"],
  "insight_summary": "one paragraph — why does the primary approach work for this specific problem?",
  "eli5": "two sentences max — explain the core idea to a 10-year-old",
  "concept_difficulty": "Easy | Medium | Hard"
}}"""

# Concept category mapping — used when inserting tags
CATEGORY_MAP = {
    "arrays": "Arrays & Strings",
    "strings": "Arrays & Strings",
    "hash maps": "Arrays & Strings",
    "hash tables": "Arrays & Strings",
    "two pointers": "Arrays & Strings",
    "prefix sums": "Arrays & Strings",
    "sliding window": "Arrays & Strings",
    "kadane": "Arrays & Strings",
    "binary search": "Sorting & Searching",
    "sorting": "Sorting & Searching",
    "merge sort": "Sorting & Searching",
    "quick sort": "Sorting & Searching",
    "recursion": "Algorithms",
    "backtracking": "Algorithms",
    "divide and conquer": "Algorithms",
    "greedy": "Algorithms",
    "bit manipulation": "Math & Bit Manipulation",
    "math": "Math & Bit Manipulation",
    "dynamic programming": "Dynamic Programming",
    "dp": "Dynamic Programming",
    "bitmask dp": "Dynamic Programming",
    "linked lists": "Data Structures",
    "stacks": "Data Structures",
    "queues": "Data Structures",
    "heaps": "Data Structures",
    "priority queue": "Data Structures",
    "trie": "Data Structures",
    "segment tree": "Data Structures",
    "binary indexed tree": "Data Structures",
    "trees": "Trees & Graphs",
    "binary trees": "Trees & Graphs",
    "binary search trees": "Trees & Graphs",
    "graphs": "Trees & Graphs",
    "breadth-first search": "Trees & Graphs",
    "depth-first search": "Trees & Graphs",
    "topological sort": "Trees & Graphs",
    "dijkstra": "Trees & Graphs",
    "union-find": "Trees & Graphs",
}


def _get_category(concept_name: str) -> str:
    lower = concept_name.lower()
    for key, cat in CATEGORY_MAP.items():
        if key in lower:
            return cat
    return "Other"


def _parse_gemini_json(raw: str) -> Optional[dict]:
    """Extract JSON from Gemini response.

    Handles:
    - Markdown code fences (```json ... ```)
    - Gemini 2.5 thinking tokens (<thinking>...</thinking>)
    - Extra text before/after the JSON object
    - Greedy brace matching to find the outermost JSON object
    """
    raw = raw.strip()

    # Strip thinking tokens emitted by Gemini 2.5
    raw = re.sub(r"<thinking>[\s\S]*?</thinking>", "", raw, flags=re.IGNORECASE).strip()

    # Strip ```json ... ``` or ``` ... ``` wrappers
    fence_match = re.search(r"```(?:json)?\s*([\s\S]+?)\s*```", raw)
    if fence_match:
        raw = fence_match.group(1).strip()

    # Try parsing directly first
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    # Find the outermost JSON object by matching braces
    start = raw.find("{")
    if start == -1:
        return None

    depth = 0
    in_string = False
    escape = False
    for i, ch in enumerate(raw[start:], start):
        if escape:
            escape = False
            continue
        if ch == "\\" and in_string:
            escape = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                candidate = raw[start:i + 1]
                try:
                    return json.loads(candidate)
                except json.JSONDecodeError:
                    break

    return None


def _get_untagged_problems(conn: sqlite3.Connection, limit: Optional[int] = None):
    """Fetch problems that haven't been tagged yet.

    Works with or without a problem statement — the tagger falls back to
    lc_tags (Topics) + title + difficulty when no statement is available.
    """
    query = """
        SELECT p.id, p.title, p.difficulty,
               COALESCE(p.statement, '') AS statement,
               COALESCE(p.lc_tags, '[]') AS lc_tags
        FROM problems p
        WHERE p.tagging_skipped = 0
          AND p.id NOT IN (
              SELECT DISTINCT problem_id FROM problem_tags
          )
        ORDER BY p.id
    """
    if limit:
        query += f" LIMIT {limit}"
    return conn.execute(query).fetchall()


def _get_or_create_tag(conn: sqlite3.Connection, name: str,
                        category: Optional[str] = None,
                        eli5: Optional[str] = None,
                        concept_difficulty: Optional[str] = None) -> int:
    """Get existing tag ID or create new one, returning the ID."""
    row = conn.execute("SELECT id FROM tags WHERE name = ?", (name,)).fetchone()
    if row:
        return row[0]
    conn.execute(
        "INSERT OR IGNORE INTO tags (name, category, eli5, concept_difficulty) VALUES (?,?,?,?)",
        (name, category or _get_category(name), eli5, concept_difficulty),
    )
    conn.commit()
    return conn.execute("SELECT id FROM tags WHERE name = ?", (name,)).fetchone()[0]


def _write_tags(conn: sqlite3.Connection, problem_id: int, data: dict):
    """Write Gemini tag output to the SQLite DB."""
    primary_concept = data.get("primary_concept", "")
    all_tags = data.get("all_tags", [])
    alternative_approaches = data.get("alternative_approaches", [])
    prerequisites = data.get("prerequisites", [])
    insight_summary = data.get("insight_summary", "")
    eli5 = data.get("eli5", "")
    concept_difficulty = data.get("concept_difficulty", "Medium")

    # Update problem with insight and eli5
    conn.execute(
        "UPDATE problems SET insight_summary=?, eli5=? WHERE id=?",
        (insight_summary, eli5, problem_id),
    )

    # Insert tags
    all_concept_names = list(dict.fromkeys(
        [primary_concept] + all_tags + alternative_approaches
    ))

    for concept_name in all_concept_names:
        if not concept_name or not concept_name.strip():
            continue
        name = concept_name.strip()
        is_primary = 1 if name == primary_concept else 0
        is_alternative = 1 if name in alternative_approaches and name != primary_concept else 0

        tag_id = _get_or_create_tag(
            conn, name,
            concept_difficulty=concept_difficulty if is_primary else None,
        )
        conn.execute(
            """INSERT OR IGNORE INTO problem_tags
               (problem_id, tag_id, is_primary, is_alternative)
               VALUES (?,?,?,?)""",
            (problem_id, tag_id, is_primary, is_alternative),
        )

    conn.commit()


async def _call_gemini(session_semaphore: asyncio.Semaphore,
                        problem: tuple,
                        rate_lock: asyncio.Lock,
                        last_call_time: list) -> Optional[tuple[int, dict]]:
    """Call Gemini API for a single problem. Returns (problem_id, parsed_data) or None."""
    import google.generativeai as genai

    problem_id, title, difficulty, statement, lc_tags_raw = problem

    try:
        lc_tags_list = json.loads(lc_tags_raw or "[]")
        lc_tags_str = ", ".join(lc_tags_list) if lc_tags_list else "none"
    except Exception:
        lc_tags_str = str(lc_tags_raw or "none")

    statement_text = statement[:4000] if statement.strip() else "(No statement available — infer from title, difficulty, and LeetCode tags above.)"
    prompt = USER_PROMPT_TEMPLATE.format(
        title=title,
        difficulty=difficulty,
        lc_tags=lc_tags_str,
        statement=statement_text,
    )

    backoff = 2.0
    for attempt in range(5):
        async with session_semaphore:
            # Enforce rate limit
            async with rate_lock:
                now = time.monotonic()
                elapsed = now - last_call_time[0]
                if elapsed < DELAY_BETWEEN_REQUESTS:
                    await asyncio.sleep(DELAY_BETWEEN_REQUESTS - elapsed)
                last_call_time[0] = time.monotonic()

            try:
                model = genai.GenerativeModel(
                    model_name=MODEL,
                    system_instruction=SYSTEM_PROMPT,
                )
                response = await asyncio.to_thread(
                    model.generate_content,
                    prompt,
                    generation_config={"temperature": 0.3, "max_output_tokens": 2048},
                )
                raw_text = response.text
                parsed = _parse_gemini_json(raw_text)
                if parsed:
                    return (problem_id, parsed)
                else:
                    print(f"  [WARN] Problem {problem_id}: invalid JSON from Gemini")
                    return None

            except Exception as e:
                err_str = str(e).lower()
                if "429" in err_str or "quota" in err_str or "rate" in err_str:
                    print(f"  [RATE LIMIT] Problem {problem_id}: waiting {backoff:.1f}s")
                    await asyncio.sleep(backoff)
                    backoff = min(backoff * 2, 60.0)
                    continue
                else:
                    print(f"  [ERROR] Problem {problem_id}: {e}")
                    return None

    print(f"  [FAIL] Problem {problem_id}: max retries exceeded")
    return None


async def _run_batch(problems: list, conn: sqlite3.Connection):
    import google.generativeai as genai
    genai.configure(api_key=GEMINI_API_KEY)

    semaphore = asyncio.Semaphore(MAX_CONCURRENT)
    rate_lock = asyncio.Lock()
    last_call_time = [time.monotonic() - DELAY_BETWEEN_REQUESTS]

    tasks = [
        _call_gemini(semaphore, p, rate_lock, last_call_time)
        for p in problems
    ]

    from tqdm import tqdm
    results = []
    for coro in tqdm(asyncio.as_completed(tasks), total=len(tasks), desc="Tagging"):
        result = await coro
        results.append(result)

    # Write successful results
    success = 0
    for result in results:
        if result:
            problem_id, data = result
            _write_tags(conn, problem_id, data)
            success += 1

    return success


def run(test_n: Optional[int] = None):
    if not GEMINI_API_KEY:
        print("[ERROR] GEMINI_API_KEY not set in pipeline/.env")
        sys.exit(1)

    if not os.path.exists(DB_PATH):
        print(f"[ERROR] DB not found at {DB_PATH}. Run ingest.py first.")
        sys.exit(1)

    conn = sqlite3.connect(DB_PATH)

    problems = _get_untagged_problems(conn, limit=test_n)
    total = len(problems)

    if total == 0:
        print("[INFO] All problems are already tagged. Nothing to do.")
        conn.close()
        return

    mode = f"TEST ({test_n} problems)" if test_n else f"FULL ({total} problems)"
    print(f"\n{'='*60}")
    print(f"Gemini Tagger — {mode}")
    print(f"Estimated time: ~{total / REQUESTS_PER_MINUTE:.0f} minutes")
    print(f"{'='*60}\n")

    if test_n:
        # For test mode: run synchronously and print raw output for inspection
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)

        for prob in problems:
            problem_id, title, difficulty, statement, lc_tags_raw = prob
            print(f"\n--- Problem {problem_id}: {title} ({difficulty}) ---")

            try:
                lc_tags_list = json.loads(lc_tags_raw or "[]")
                lc_tags_str = ", ".join(lc_tags_list) if lc_tags_list else "none"
            except Exception:
                lc_tags_str = str(lc_tags_raw or "none")

            statement_text = statement[:4000] if statement.strip() else "(No statement available — infer from title, difficulty, and LeetCode tags above.)"
            prompt = USER_PROMPT_TEMPLATE.format(
                title=title,
                difficulty=difficulty,
                lc_tags=lc_tags_str,
                statement=statement_text,
            )

            model = genai.GenerativeModel(
                model_name=MODEL,
                system_instruction=SYSTEM_PROMPT,
            )
            response = model.generate_content(
                prompt,
                generation_config={"temperature": 0.3, "max_output_tokens": 2048},
            )
            raw = response.text
            print("Raw Gemini response:")
            print(raw.encode("ascii", "replace").decode("ascii"))
            print()

            parsed = _parse_gemini_json(raw)
            if parsed:
                _write_tags(conn, problem_id, parsed)
                print(f"  [OK] Tags written for problem {problem_id}")
            else:
                print(f"  [FAIL] Failed to parse JSON for problem {problem_id}")

            time.sleep(DELAY_BETWEEN_REQUESTS)

        print(f"\n[TEST COMPLETE] Review the output above before running the full pipeline.")

    else:
        # Full async run in batches
        total_success = 0
        for batch_start in range(0, total, CHECKPOINT_EVERY):
            batch = problems[batch_start: batch_start + CHECKPOINT_EVERY]
            print(f"\n[Batch {batch_start // CHECKPOINT_EVERY + 1}] "
                  f"Problems {batch_start + 1}-{batch_start + len(batch)}")
            success = asyncio.run(_run_batch(batch, conn))
            total_success += success
            print(f"  >> {success}/{len(batch)} tagged successfully")

        print(f"\n[DONE] {total_success}/{total} problems tagged.")

    conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Gemini concept tagger")
    parser.add_argument("--test", type=int, metavar="N",
                        help="Run in test mode on first N problems only")
    args = parser.parse_args()
    run(test_n=args.test)
