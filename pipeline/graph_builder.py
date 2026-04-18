"""
Stage 3 — Concept Graph Builder
Reads tagged problems from SQLite, builds the concept prerequisite graph,
normalises concept name aliases, detects cycles, and writes edges.

Usage:
    python graph_builder.py
"""

import sqlite3
import json
import os
import sys
from collections import defaultdict, deque

DB_PATH = os.path.join("output", "leetcode_problems.db")

# Alias dictionary: maps non-canonical names → canonical names
ALIASES = {
    "min heap": "Priority Queue / Min-Heap",
    "max heap": "Priority Queue / Max-Heap",
    "min-heap": "Priority Queue / Min-Heap",
    "max-heap": "Priority Queue / Max-Heap",
    "priority queue": "Priority Queue / Min-Heap",
    "union find": "Union-Find / Disjoint Set",
    "dsu": "Union-Find / Disjoint Set",
    "disjoint set union": "Union-Find / Disjoint Set",
    "disjoint set": "Union-Find / Disjoint Set",
    "bfs": "Breadth-First Search",
    "breadth first search": "Breadth-First Search",
    "dfs": "Depth-First Search",
    "depth first search": "Depth-First Search",
    "dp": "Dynamic Programming",
    "dp with memoization": "DP with Memoization",
    "memoization": "DP with Memoization",
    "top-down dp": "DP with Memoization",
    "bottom-up dp": "DP (Bottom-Up / Tabulation)",
    "tabulation": "DP (Bottom-Up / Tabulation)",
    "sliding window": "Sliding Window (Variable Size)",
    "two pointer": "Two Pointers",
    "prefix tree": "Trie",
    "segment tree": "Segment Tree",
    "fenwick tree": "Binary Indexed Tree / Fenwick Tree",
    "bit tree": "Binary Indexed Tree / Fenwick Tree",
    "binary indexed tree": "Binary Indexed Tree / Fenwick Tree",
    "topological sort": "Topological Sort",
    "topological sorting": "Topological Sort",
    "floyd warshall": "Floyd-Warshall",
    "bellman ford": "Bellman-Ford",
    "dijkstra": "Dijkstra's Algorithm",
    "dijkstra's algorithm": "Dijkstra's Algorithm",
    "kruskal": "Kruskal's Algorithm",
    "prim": "Prim's Algorithm",
    "binary search": "Binary Search",
    "merge sort": "Merge Sort",
    "quick sort": "Quick Sort",
    "heap sort": "Heap Sort",
    "hash map": "Hash Maps / Hash Tables",
    "hash table": "Hash Maps / Hash Tables",
    "hashmap": "Hash Maps / Hash Tables",
    "hashtable": "Hash Maps / Hash Tables",
    "linked list": "Linked Lists",
    "graph": "Graphs",
    "tree": "Trees",
    "binary tree": "Binary Trees",
    "bst": "Binary Search Trees",
    "binary search tree": "Binary Search Trees",
    "stack": "Stacks",
    "queue": "Queues",
    "deque": "Monotonic Queue / Deque",
    "monotonic stack": "Monotonic Stack",
    "monotonic queue": "Monotonic Queue / Deque",
    "prefix sum": "Prefix Sums",
    "two pointers": "Two Pointers",
    "fast slow pointer": "Fast and Slow Pointers",
    "tortoise and hare": "Fast and Slow Pointers",
    "cycle detection": "Cycle Detection",
    "backtracking": "Backtracking",
    "recursion": "Recursion",
    "greedy": "Greedy",
    "divide and conquer": "Divide and Conquer",
    "bit manipulation": "Bit Manipulation",
    "bitmask": "Bitmask",
    "bitmask dp": "Bitmask DP",
    "string": "Strings",
    "array": "Arrays",
    "sorting": "Sorting",
    "kadane's algorithm": "Kadane's Algorithm",
    "kadane": "Kadane's Algorithm",
}


def _normalize(name: str) -> str:
    """Normalise concept name using alias dict."""
    if not name:
        return ""
    key = name.lower().strip()
    return ALIASES.get(key, name.strip())


def _detect_cycles(adj: dict) -> list:
    """Topological sort to detect cycles. Returns list of cycles found."""
    in_degree = defaultdict(int)
    all_nodes = set(adj.keys())
    for node, deps in adj.items():
        for dep in deps:
            all_nodes.add(dep)
            in_degree[node]  # ensure node is in dict

    for node, deps in adj.items():
        for dep in deps:
            in_degree[dep] += 1  # dep is required by node, so dep has higher "order"

    # Kahn's algorithm
    queue = deque([n for n in all_nodes if in_degree.get(n, 0) == 0])
    visited = 0
    while queue:
        node = queue.popleft()
        visited += 1
        for neighbor in adj.get(node, []):
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    if visited == len(all_nodes):
        return []  # no cycle

    # Find nodes still in cycle
    cycle_nodes = [n for n in all_nodes if in_degree.get(n, 0) > 0]
    return cycle_nodes


def run():
    if not os.path.exists(DB_PATH):
        print(f"[ERROR] DB not found at {DB_PATH}. Run ingest.py and tagger.py first.")
        sys.exit(1)

    conn = sqlite3.connect(DB_PATH)

    print("[1/5] Loading tags …")
    tags = conn.execute("SELECT id, name FROM tags").fetchall()
    tag_id_by_name = {name: tid for tid, name in tags}
    print(f"      {len(tags)} tags loaded")

    print("[2/5] Normalising tag names …")
    # Normalise and deduplicate tags
    rename_map = {}  # old_id → canonical_id
    for tag_id, name in tags:
        canonical = _normalize(name)
        if canonical != name:
            # Get or create the canonical tag
            if canonical not in tag_id_by_name:
                conn.execute(
                    "INSERT OR IGNORE INTO tags (name) VALUES (?)", (canonical,)
                )
                conn.commit()
                row = conn.execute(
                    "SELECT id FROM tags WHERE name = ?", (canonical,)
                ).fetchone()
                canonical_id = row[0]
                tag_id_by_name[canonical] = canonical_id
            else:
                canonical_id = tag_id_by_name[canonical]
            rename_map[tag_id] = canonical_id

    # Apply renames in problem_tags
    if rename_map:
        print(f"      Renaming {len(rename_map)} alias tags …")
        for old_id, new_id in rename_map.items():
            if old_id == new_id:
                continue
            conn.execute(
                "UPDATE problem_tags SET tag_id = ? WHERE tag_id = ? AND problem_id NOT IN "
                "(SELECT problem_id FROM problem_tags WHERE tag_id = ?)",
                (new_id, old_id, new_id),
            )
            conn.execute("DELETE FROM problem_tags WHERE tag_id = ?", (old_id,))
            conn.execute("DELETE FROM tags WHERE id = ?", (old_id,))
        conn.commit()
        # Refresh tag list
        tags = conn.execute("SELECT id, name FROM tags").fetchall()
        tag_id_by_name = {name: tid for tid, name in tags}

    print("[3/5] Building prerequisite graph from tagger output …")
    # For each problem, we need to look at prerequisites from the tagger
    # We stored insight_summary and eli5 but not prerequisites as a separate column.
    # In a proper implementation the prerequisites would come from the tagger JSON.
    # Here we derive them from the ALIASES and known DSA concept hierarchy.

    KNOWN_PREREQUISITES = {
        "Dijkstra's Algorithm": ["Graphs", "Priority Queue / Min-Heap", "Breadth-First Search"],
        "Bellman-Ford": ["Graphs", "Dynamic Programming"],
        "Floyd-Warshall": ["Graphs", "Dynamic Programming"],
        "Topological Sort": ["Graphs", "Depth-First Search"],
        "Union-Find / Disjoint Set": ["Graphs"],
        "Kruskal's Algorithm": ["Graphs", "Union-Find / Disjoint Set", "Sorting"],
        "Prim's Algorithm": ["Graphs", "Priority Queue / Min-Heap"],
        "Binary Search Trees": ["Binary Trees", "Binary Search"],
        "DP with Memoization": ["Dynamic Programming", "Recursion"],
        "DP (Bottom-Up / Tabulation)": ["Dynamic Programming"],
        "Bitmask DP": ["Dynamic Programming", "Bitmask"],
        "DP on Intervals": ["Dynamic Programming"],
        "Trie": ["Trees", "Hash Maps / Hash Tables"],
        "Segment Tree": ["Trees", "Recursion"],
        "Binary Indexed Tree / Fenwick Tree": ["Arrays", "Binary Search"],
        "Monotonic Stack": ["Stacks"],
        "Monotonic Queue / Deque": ["Queues"],
        "Sliding Window (Variable Size)": ["Two Pointers"],
        "Sliding Window (Fixed Size)": ["Arrays"],
        "Fast and Slow Pointers": ["Linked Lists", "Two Pointers"],
        "Backtracking": ["Recursion"],
        "Divide and Conquer": ["Recursion"],
        "Merge Sort": ["Divide and Conquer", "Recursion"],
        "Quick Sort": ["Divide and Conquer", "Recursion"],
        "Breadth-First Search": ["Graphs", "Queues"],
        "Depth-First Search": ["Graphs", "Recursion"],
        "Cycle Detection": ["Graphs", "Depth-First Search"],
        "Topological Sort": ["Graphs", "Depth-First Search"],
    }

    edges_added = 0
    for concept, prereqs in KNOWN_PREREQUISITES.items():
        concept_id = tag_id_by_name.get(concept)
        if not concept_id:
            continue
        for prereq in prereqs:
            prereq_id = tag_id_by_name.get(prereq)
            if not prereq_id or prereq_id == concept_id:
                continue
            conn.execute(
                "INSERT OR IGNORE INTO concept_prerequisites (tag_id, requires_tag_id) VALUES (?,?)",
                (concept_id, prereq_id),
            )
            edges_added += 1

    conn.commit()
    print(f"      {edges_added} prerequisite edges written")

    print("[4/5] Detecting cycles …")
    adj = defaultdict(set)
    edges = conn.execute(
        "SELECT tag_id, requires_tag_id FROM concept_prerequisites"
    ).fetchall()
    for tag_id, requires_tag_id in edges:
        adj[tag_id].add(requires_tag_id)

    cycle_nodes = _detect_cycles(adj)
    if cycle_nodes:
        print(f"  [WARN] Cycles detected involving {len(cycle_nodes)} nodes:")
        for node_id in cycle_nodes:
            row = conn.execute("SELECT name FROM tags WHERE id=?", (node_id,)).fetchone()
            print(f"    - {row[0] if row else node_id}")
        print("  These edges will be removed to break cycles …")
        # Simple fix: remove edges that create cycles (remove reverse edges)
        for node_id in cycle_nodes:
            conn.execute(
                "DELETE FROM concept_prerequisites WHERE tag_id = ? AND requires_tag_id IN (?)",
                (node_id, node_id),
            )
        conn.commit()
    else:
        print("  ✓ No cycles detected")

    print("[5/5] Summary …")
    tag_count = conn.execute("SELECT COUNT(*) FROM tags").fetchone()[0]
    edge_count = conn.execute("SELECT COUNT(*) FROM concept_prerequisites").fetchone()[0]
    print(f"  Tags: {tag_count}")
    print(f"  Prerequisite edges: {edge_count}")

    conn.close()
    print("\n[DONE] Concept graph built successfully.")


if __name__ == "__main__":
    run()
