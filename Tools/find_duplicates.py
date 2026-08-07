"""
Find literal duplicate `text` values anywhere in the corpus, regardless of
label or split -- matching the trainer's actual check, which groups ALL
rows by normalizeMerchant(text) and requires every group to have exactly
one member.

Usage: python3 find_duplicates.py merchant_categories_v3.csv
"""
import csv
import sys
from collections import defaultdict
from td_normalize import normalize_merchant

path = sys.argv[1] if len(sys.argv) > 1 else "merchant_categories_v3.csv"

with open(path, newline="", encoding="utf-8") as f:
    rows = list(csv.DictReader(f))

by_text = defaultdict(list)
for r in rows:
    by_text[normalize_merchant(r["text"])].append(r)

dupes = {text: group for text, group in by_text.items() if len(group) > 1}

print(f"Total rows: {len(rows)}  |  Unique normalized texts: {len(by_text)}")
print(f"Duplicate normalized text values: {len(dupes)}")
n_dupe_rows = sum(len(g) for g in dupes.values())
print(f"Total rows involved in a duplicate: {n_dupe_rows}  (would drop {n_dupe_rows - len(dupes)} to reach full uniqueness)")

if dupes:
    print("\n--- First 20 ---")
    for norm, group in list(dupes.items())[:20]:
        print(f"  normalized -> '{norm}'")
        for g in group:
            print(f"      raw='{g['text']}'  label={g['label']}  split={g['split']}  family={g['merchant_family']}")

# Also check the trainer's other hard requirements while we're here
expected_labels = {"Rent", "Tuition", "Food", "Transport", "Subscriptions",
                    "Transfer", "Clothes", "Other", "Income", "Entertainment"}
found_labels = set(r["label"] for r in rows)
extra = found_labels - expected_labels
missing = expected_labels - found_labels
if extra:
    print(f"\nLABELS NOT IN TRAINER'S expectedLabels (will fail): {sorted(extra)}")
if missing:
    print(f"\nLABELS MISSING FROM CORPUS (trainer requires all): {sorted(missing)}")

for label in sorted(expected_labels):
    for split in ["train", "validation", "test"]:
        if not any(r["label"] == label and r["split"] == split for r in rows):
            print(f"MISSING: no {label} example in split '{split}'")

family_splits = defaultdict(set)
for r in rows:
    family_splits[r["merchant_family"].lower()].add(r["split"])
crossing = {fam: splits for fam, splits in family_splits.items() if len(splits) > 1}
if crossing:
    print(f"\nFAMILIES CROSSING SPLITS (will fail): {crossing}")