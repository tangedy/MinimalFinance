"""
Find and classify duplicate `text` values in a merchant_categories-style CSV.

Usage: python3 find_duplicates.py merchant_categories_v3.csv
"""
import csv
import sys
from collections import defaultdict

path = sys.argv[1] if len(sys.argv) > 1 else "merchant_categories_v3.csv"

with open(path, newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f))

by_text = defaultdict(list)
for r in rows:
    by_text[r["text"].strip().lower()].append(r)

harmless = []       # same text, same label, same split -> just redundant
leakage = []        # same text, same label, different splits -> must fix
conflicts = []      # same text, different labels -> needs manual review

for text, group in by_text.items():
    if len(group) < 2:
        continue
    labels = set(g["label"] for g in group)
    splits = set(g["split"] for g in group)
    if len(labels) > 1:
        conflicts.append((text, group))
    elif len(splits) > 1:
        leakage.append((text, group))
    else:
        harmless.append((text, group))
        print(f"  '{group[0]['text']}' -> {[(g['label'], g['split'], g['merchant_family']) for g in group]}")

print(f"Total rows: {len(rows)}  |  Unique texts: {len(by_text)}")
print(f"Harmless duplicates (safe to just drop extras): {len(harmless)}")
print(f"LEAKAGE (same text across train + val/test):     {len(leakage)}")
print(f"LABEL CONFLICTS (same text, different labels):   {len(conflicts)}")

if leakage:
    print("\n--- Leakage examples (first 10) ---")
    for text, group in leakage[:10]:
        print(f"  '{group[0]['text']}' -> {[(g['label'], g['split'], g['merchant_family']) for g in group]}")

if conflicts:
    print("\n--- Label conflicts (first 10) ---")
    for text, group in conflicts[:10]:
        print(f"  '{group[0]['text']}' -> {[(g['label'], g['split'], g['merchant_family']) for g in group]}")
