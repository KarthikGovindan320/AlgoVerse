# AlgoVerse Pipeline

Builds the `leetcode_problems.db` SQLite file from the Kaggle dataset.

## Setup

```bash
cd pipeline
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
```

Create `pipeline/.env`:
```
GEMINI_API_KEY=your_key_here
```

Place the Kaggle CSV at `pipeline/data/leetcode_problems.csv`.

## Run

```bash
# Stage 1 — Ingest CSV to SQLite (~30 seconds)
python ingest.py

# Stage 2 — Test Gemini tagger on 5 problems first
python tagger.py --test 5

# Stage 2 — Full run after test passes (~60-90 minutes)
python tagger.py

# Stage 3 — Build concept prerequisite graph (~2 minutes)
python graph_builder.py

# Stage 4 — Validate output before copying
python validate.py

# Copy to Flutter assets
copy output\leetcode_problems.db ..\assets\data\leetcode_problems.db
```

## Notes

- `ingest.py` and `tagger.py` are both resume-safe — re-running skips already-processed rows.
- Never commit `data/*.csv` or `output/*.db` to git (they are in .gitignore).
- The final `leetcode_problems.db` in `assets/data/` IS committed (via Git LFS).
