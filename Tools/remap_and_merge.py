"""
Remap DoDataThings/us-bank-transaction-categories-v2 into your taxonomy and
merge it underneath your real merchant_categories_v2.csv as a base layer.

--------------------------------------------------------------------------
STEP 0 — get the raw data (can't be done from this sandbox, no HF network
access here). On your own machine:

    pip install datasets
    python3 -c "
from datasets import load_dataset
ds = load_dataset('DoDataThings/us-bank-transaction-categories-v2')
ds['train'].to_csv('us_transactions_raw.csv')
"

That gives you us_transactions_raw.csv with columns: description, category
Put it next to this script, then run:

    python3 remap_and_merge.py us_transactions_raw.csv merchant_categories_v2.csv
--------------------------------------------------------------------------
"""

import csv
import re
import random
import sys
from collections import defaultdict
 
random.seed(42)
 
RAW_PATH = sys.argv[1] if len(sys.argv) > 1 else "us_transactions_raw.csv"
REAL_PATH = sys.argv[2] if len(sys.argv) > 2 else "merchant_categories_v2.csv"
OUT_PATH = "merchant_categories_v3.csv"
 
# How many unique merchant strings to keep PER remapped category. A
# lightweight embedding/few-shot model doesn't need (or benefit from)
# 4,000 examples per class the way a big transformer does.
CAP_UNIQUE_PER_CATEGORY = 400
 
# How many times a single train-split string is allowed to repeat.
# Real repeat frequency (you shop at Target a lot) is legitimate signal
# for a MaxEnt/bag-of-words model -- capped so one ultra-common template
# string can't numerically swamp everything else in its category.
MAX_DUPES_PER_TEXT_IN_TRAIN = 3
 
# Their 17 categories -> your taxonomy. Categories mapped to None are
# dropped entirely (not relevant to a student's transactions).
CATEGORY_MAP = {
    "Restaurants":    "Food",
    "Groceries":      "Food",
    "Transportation": "Transport",
    "Entertainment":  "Entertainment",   # new category, absorbs Gambling
    "Subscription":   "Subscriptions",
    "Rent":           "Rent",
    "Education":      "Tuition",
    "Transfer":       "Transfer",
    "Income":         "Income",
    "Shopping":       "Other",
    "Utilities":      "Other",
    "Healthcare":     "Other",
    "Insurance":      "Other",
    "Travel":         "Other",
    "Personal Care":  "Other",
    "Fees":           "Other",
    "Mortgage":       None,              # not relevant, drop
}
 
SUFFIX_RE = re.compile(r"\s+_[A-Z]{1,3}$")  # strips trailing _V / _M / _F / _PA etc.
 
 
def clean_text(raw_desc: str) -> str:
    """Strip the [debit]/[credit] tag out into its own value, normalize
    whitespace. We keep sign as a SEPARATE column rather than baking it
    into `text`, since your real corpus doesn't currently carry a sign
    column -- see note at the bottom on how to use it."""
    m = re.match(r"^\[(debit|credit)\]\s*(.*)$", raw_desc.strip())
    sign, text = (m.group(1), m.group(2)) if m else (None, raw_desc.strip())
    text = re.sub(r"\s+", " ", text).strip()
    return sign, text
 
 
def strip_td_suffix(text: str) -> str:
    """Match the same normalization applied to your own real rows --
    strip trailing TD transaction-type codes so train/inference text
    formats stay consistent."""
    return SUFFIX_RE.sub("", text).strip()
 
 
# --- Load and remap the bulk dataset ---
by_category = defaultdict(list)
with open(RAW_PATH, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        mapped = CATEGORY_MAP.get(row["category"])
        if mapped is None:
            continue
        sign, text = clean_text(row["description"])
        by_category[mapped].append((text, sign))
 
# --- Downsample each mapped category, splitting by UNIQUE text so no
# string can ever span train + validation/test, then reintroduce
# realistic repeats back into train only ---
bulk_rows = []
for label, examples in by_category.items():
    # Count how many times each unique string occurs in the raw data --
    # this is the real-world frequency signal worth preserving.
    freq = defaultdict(int)
    sign_for_text = {}
    for text, sign in examples:
        key = text.lower()
        freq[key] += 1
        sign_for_text.setdefault(key, (text, sign))  # keep original casing
 
    unique_texts = list(freq.keys())
    random.shuffle(unique_texts)
    unique_texts = unique_texts[:CAP_UNIQUE_PER_CATEGORY]
 
    # Split UNIQUE strings (not rows) 80/10/10 -- this is what guarantees
    # no string ends up in more than one split.
    n = len(unique_texts)
    n_val = max(1, int(n * 0.1))
    n_test = max(1, int(n * 0.1))
    split_for_key = {}
    for key in unique_texts[: n - n_val - n_test]:
        split_for_key[key] = "train"
    for key in unique_texts[n - n_val - n_test : n - n_test]:
        split_for_key[key] = "validation"
    for key in unique_texts[n - n_test :]:
        split_for_key[key] = "test"
 
    for key, split in split_for_key.items():
        text, sign = sign_for_text[key]
        family_suffix = f"_{sign}" if sign else ""
        n_copies = 1 if split != "train" else min(freq[key], MAX_DUPES_PER_TEXT_IN_TRAIN)
        for _ in range(n_copies):
            bulk_rows.append({
                "text": text,
                "label": label,
                "merchant_family": f"bulk_{label.lower()}{family_suffix}",
                "split": split,
            })
 
# --- Load your real corpus exactly as-is ---
with open(REAL_PATH, newline="", encoding="utf-8") as f:
    real_rows = list(csv.DictReader(f))
for r in real_rows:
    r["text"] = strip_td_suffix(r["text"])
 
# --- Write combined corpus: same 4 columns as your original schema ---
fieldnames = ["text", "label", "merchant_family", "split"]
real_rows = [{k: r[k] for k in fieldnames} for r in real_rows]
with open(OUT_PATH, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(real_rows)
    writer.writerows(bulk_rows)
 
print(f"Wrote {OUT_PATH}: {len(real_rows)} real rows + {len(bulk_rows)} bulk rows")
from collections import Counter
c = Counter(r["label"] for r in real_rows + bulk_rows)
for label, n in sorted(c.items(), key=lambda x: -x[1]):
    print(f"  {label:15s} {n}")
 
print("""
NOTE on direction (debit/credit):
Output is your original 4 columns only (text,label,merchant_family,split)
so it drops straight into your existing trainer. Sign info from the bulk
dataset is preserved only as a suffix on merchant_family (e.g.
bulk_income_credit) in case you want to inspect/filter it later -- it is
NOT a training column and Create ML won't see it as a feature.
 
If you want direction as an actual signal -- relevant for the UNIV WTRLOO /
FANDUEL cases we discussed -- the zero-architecture-change way to do it is
to prepend it directly into `text` at both train and inference time, e.g.
"[debit] UBER CANADA/UBE", so it becomes just another token instead of a
new column/feature.
""")