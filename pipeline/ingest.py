"""
Stage 1 — CSV Ingest
Reads the Kaggle LeetCode CSV and writes all rows to the local SQLite DB.
Resume-safe: INSERT OR IGNORE means re-running never duplicates rows.

Usage (with venv activated):
    python ingest.py
"""

import sqlite3
import html2text
import pandas as pd
import json
import os
import re
import sys

CSV_PATH = os.path.join("data", "leetcode_problems.csv")
DB_PATH = os.path.join("output", "leetcode_problems.db")

# Column name normalisation — maps any Kaggle column variant to our internal name
COLUMN_MAP = {
    # ID
    "questionid": "id",
    "question id": "id",
    "frontendquestionid": "id",
    "id": "id",
    # Slug
    "titleslug": "slug",
    "title slug": "slug",
    "slug": "slug",
    # Title
    "title": "title",
    "question title": "title",
    # Difficulty
    "difficulty": "difficulty",
    # Statement / description
    "content": "statement",
    "description": "statement",
    "body": "statement",
    "question": "statement",
    "questionbody": "statement",
    # Acceptance rate
    "acrate": "acceptance_rate",
    "acceptance_rate": "acceptance_rate",
    "acceptancerate": "acceptance_rate",
    "acceptance rate": "acceptance_rate",
    # Premium
    "ispaidonly": "is_premium",
    "is_premium": "is_premium",
    "paidonly": "is_premium",
    "paid only": "is_premium",
    # LeetCode's own tags
    "topictags": "lc_tags",
    "topic_tags": "lc_tags",
    "topic tags": "lc_tags",
    "tags": "lc_tags",
    # Hints
    "hints": "hints",
    # Example test cases
    "sampletestcase": "example_testcases",
    "exampletestcases": "example_testcases",
    "example testcases": "example_testcases",
    # Likes
    "likes": "likes",
    # Similar questions
    "similarquestions": "similar_questions",
    "similar questions": "similar_questions",
}

DDL = """
CREATE TABLE IF NOT EXISTS problems (
    id               INTEGER PRIMARY KEY,
    slug             TEXT    UNIQUE NOT NULL,
    title            TEXT    NOT NULL,
    difficulty       TEXT    NOT NULL,
    statement        TEXT,
    example_testcases TEXT,
    hints            TEXT,
    acceptance_rate  REAL,
    is_premium       INTEGER DEFAULT 0,
    tagging_skipped  INTEGER DEFAULT 0,
    insight_summary  TEXT,
    eli5             TEXT,
    lc_tags          TEXT,
    likes            INTEGER,
    similar_questions TEXT
);

CREATE TABLE IF NOT EXISTS tags (
    id                  INTEGER PRIMARY KEY AUTOINCREMENT,
    name                TEXT    UNIQUE NOT NULL,
    category            TEXT,
    concept_difficulty  TEXT,
    eli5                TEXT
);

CREATE TABLE IF NOT EXISTS problem_tags (
    problem_id   INTEGER NOT NULL,
    tag_id       INTEGER NOT NULL,
    is_primary   INTEGER DEFAULT 0,
    is_alternative INTEGER DEFAULT 0,
    PRIMARY KEY (problem_id, tag_id),
    FOREIGN KEY (problem_id) REFERENCES problems(id),
    FOREIGN KEY (tag_id)     REFERENCES tags(id)
);

CREATE TABLE IF NOT EXISTS concept_prerequisites (
    tag_id          INTEGER NOT NULL,
    requires_tag_id INTEGER NOT NULL,
    PRIMARY KEY (tag_id, requires_tag_id),
    FOREIGN KEY (tag_id)          REFERENCES tags(id),
    FOREIGN KEY (requires_tag_id) REFERENCES tags(id)
);

CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT
);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_problems_slug       ON problems(slug);
CREATE INDEX IF NOT EXISTS idx_problem_tags_tag    ON problem_tags(tag_id);
CREATE INDEX IF NOT EXISTS idx_problem_tags_prob   ON problem_tags(problem_id);
CREATE INDEX IF NOT EXISTS idx_concept_prereq_tag  ON concept_prerequisites(tag_id);
"""

HTML_CONVERTER = html2text.HTML2Text()
HTML_CONVERTER.ignore_links = False
HTML_CONVERTER.ignore_images = True
HTML_CONVERTER.body_width = 0  # no line wrapping


def _looks_like_html(text: str) -> bool:
    return bool(re.search(r"<[a-z][^>]*>", text, re.IGNORECASE))


def _clean_statement(raw: str) -> str:
    if not raw or not str(raw).strip():
        return ""
    raw = str(raw).strip()
    if _looks_like_html(raw):
        raw = HTML_CONVERTER.handle(raw)
    # Remove null bytes
    raw = raw.replace("\x00", "").strip()
    return raw


def _normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Rename DataFrame columns to our internal names using COLUMN_MAP."""
    rename = {}
    for col in df.columns:
        key = col.lower().strip()
        if key in COLUMN_MAP:
            rename[col] = COLUMN_MAP[key]
    df = df.rename(columns=rename)

    # Print unmapped columns so we can extend COLUMN_MAP if needed
    known = set(COLUMN_MAP.values())
    unmapped = [c for c in df.columns if c not in known]
    if unmapped:
        print(f"[INFO] Unmapped CSV columns (ignored): {unmapped}")

    return df


def _parse_bool(val) -> int:
    if isinstance(val, bool):
        return int(val)
    if isinstance(val, (int, float)):
        return int(bool(val))
    s = str(val).lower().strip()
    return 1 if s in ("true", "1", "yes") else 0


def _parse_tags(val) -> str:
    """Normalise the LeetCode tags field to a JSON array string."""
    if not val or str(val).strip() in ("", "nan", "None"):
        return "[]"
    s = str(val).strip()
    # Already a JSON array
    if s.startswith("["):
        try:
            parsed = json.loads(s)
            # Each element may be a dict {"name": "..."} or a string
            names = []
            for item in parsed:
                if isinstance(item, dict):
                    names.append(item.get("name") or item.get("slug", ""))
                else:
                    names.append(str(item))
            return json.dumps([n for n in names if n])
        except json.JSONDecodeError:
            pass
    # Comma-separated string
    parts = [p.strip() for p in re.split(r"[,|;]", s) if p.strip()]
    return json.dumps(parts)


def run():
    os.makedirs("output", exist_ok=True)

    if not os.path.exists(CSV_PATH):
        print(f"[ERROR] CSV not found at {CSV_PATH}")
        print("Download the Kaggle dataset and place it at pipeline/data/leetcode_problems.csv")
        sys.exit(1)

    print(f"[1/4] Reading CSV: {CSV_PATH}")
    df = pd.read_csv(CSV_PATH, low_memory=False, encoding="utf-8", on_bad_lines="skip")
    print(f"      {len(df)} rows found. Columns: {list(df.columns)}")

    df = _normalize_columns(df)

    # Ensure required columns exist
    for col in ("id", "slug", "title", "difficulty"):
        if col not in df.columns:
            print(f"[ERROR] Required column '{col}' not found after mapping.")
            print("        Please extend COLUMN_MAP in ingest.py with the correct CSV column names.")
            sys.exit(1)

    print(f"[2/4] Connecting to DB: {DB_PATH}")
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.executescript(DDL)
    conn.commit()

    print("[3/4] Inserting rows …")
    inserted = skipped_premium = skipped_empty = 0

    for _, row in df.iterrows():
        try:
            problem_id = int(float(row.get("id", 0)))
            if problem_id <= 0:
                continue

            slug = str(row.get("slug", "")).strip()
            title = str(row.get("title", "")).strip()
            difficulty = str(row.get("difficulty", "Medium")).strip().capitalize()

            if not slug or not title:
                continue

            is_premium = _parse_bool(row.get("is_premium", False))
            raw_statement = row.get("statement", "")
            statement = _clean_statement(raw_statement) if raw_statement else ""
            tagging_skipped = 1 if (not statement or is_premium) else 0

            acceptance_rate_raw = row.get("acceptance_rate", None)
            acceptance_rate = None
            if acceptance_rate_raw is not None:
                try:
                    ar = float(str(acceptance_rate_raw).replace("%", "").strip())
                    # Normalise to 0–1 if given as percentage
                    acceptance_rate = ar / 100.0 if ar > 1.0 else ar
                except ValueError:
                    pass

            hints_raw = row.get("hints", None)
            hints = None
            if hints_raw and str(hints_raw).strip() not in ("nan", "None", ""):
                try:
                    parsed = json.loads(str(hints_raw))
                    hints = json.dumps(parsed if isinstance(parsed, list) else [str(parsed)])
                except (json.JSONDecodeError, TypeError):
                    hints = json.dumps([str(hints_raw)])

            example_testcases = str(row.get("example_testcases", "") or "").strip() or None
            lc_tags = _parse_tags(row.get("lc_tags", ""))
            likes_raw = row.get("likes", None)
            likes = None
            try:
                likes = int(float(str(likes_raw))) if likes_raw and str(likes_raw) not in ("nan", "None") else None
            except (ValueError, TypeError):
                pass
            similar_questions = str(row.get("similar_questions", "") or "").strip() or None

            cursor.execute(
                """
                INSERT OR IGNORE INTO problems
                  (id, slug, title, difficulty, statement, example_testcases,
                   hints, acceptance_rate, is_premium, tagging_skipped,
                   lc_tags, likes, similar_questions)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
                """,
                (
                    problem_id, slug, title, difficulty, statement,
                    example_testcases, hints, acceptance_rate,
                    is_premium, tagging_skipped, lc_tags, likes, similar_questions,
                ),
            )

            if cursor.rowcount > 0:
                inserted += 1
                if is_premium:
                    skipped_premium += 1
                if not statement:
                    skipped_empty += 1
            else:
                skipped_empty += 1  # already exists

        except Exception as e:
            print(f"[WARN] Skipping row due to error: {e}")
            continue

    # Write meta version
    cursor.execute(
        "INSERT OR REPLACE INTO meta (key, value) VALUES ('db_version', '1.0.0')"
    )
    conn.commit()
    conn.close()

    total = cursor.execute  # just for reference
    print(f"[4/4] Done.")
    print(f"      Inserted : {inserted} problems")
    print(f"      Premium  : {skipped_premium} (tagging skipped)")
    print(f"      No stmt  : {skipped_empty} (tagging skipped)")
    print(f"      DB at    : {DB_PATH}")


if __name__ == "__main__":
    run()
