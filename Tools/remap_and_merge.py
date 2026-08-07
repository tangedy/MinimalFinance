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
from td_normalize import normalize_merchant

random.seed(42)

RAW_PATH = sys.argv[1] if len(sys.argv) > 1 else "us_transactions_raw.csv"
REAL_PATH = sys.argv[2] if len(sys.argv) > 2 else "merchant_categories_v2.csv"
OUT_PATH = "merchant_categories_v3.csv"

# How many unique merchant strings to keep PER remapped category. A
# lightweight embedding/few-shot model doesn't need (or benefit from)
# 4,000 examples per class the way a big transformer does.
CAP_UNIQUE_PER_CATEGORY = 400

# Your trainer requires every `text` value to be globally unique across
# the whole corpus -- no repeats anywhere, in any split. So repeated raw
# merchant strings (TARGET appearing 200 times) get folded down to ONE
# row. Frequency information is not preserved as duplicate rows; if you
# want frequency weighting later, that needs a `weight`/`count` column
# added to the trainer itself, not duplicate text rows.

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


# --- Load your real corpus FIRST -- it always wins on any collision ---
with open(REAL_PATH, newline="", encoding="utf-8") as f:
    real_rows = list(csv.DictReader(f))
for r in real_rows:
    r["text"] = strip_td_suffix(r["text"])

fieldnames = ["text", "label", "merchant_family", "split"]
real_rows = [{k: r[k] for k in fieldnames} for r in real_rows]

# Key by the trainer's own normalization -- this is what actually
# determines uniqueness for it, not raw casing/whitespace.
global_seen_norm = set(normalize_merchant(r["text"]) for r in real_rows)

# --- Load and remap the bulk dataset ---
by_category = defaultdict(list)
with open(RAW_PATH, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f):
        mapped = CATEGORY_MAP.get(row["category"])
        if mapped is None:
            continue
        sign, text = clean_text(row["description"])
        by_category[mapped].append((text, sign))

# --- Downsample each mapped category, splitting by UNIQUE normalized text
# so nothing the trainer would consider a duplicate slips through, in
# any split, in any category, against your real rows or each other ---
bulk_rows = []

for label, examples in by_category.items():
    seen_in_category = {}
    for text, sign in examples:
        key = normalize_merchant(text)
        if key in global_seen_norm:
            continue  # collides with real data or an earlier category
        if key not in seen_in_category:
            seen_in_category[key] = (text, sign)

    unique_items = list(seen_in_category.values())
    random.shuffle(unique_items)
    unique_items = unique_items[:CAP_UNIQUE_PER_CATEGORY]

    n = len(unique_items)
    n_val = max(1, int(n * 0.1))
    n_test = max(1, int(n * 0.1))
    split_groups = {
        "train": unique_items[: n - n_val - n_test],
        "validation": unique_items[n - n_val - n_test : n - n_test],
        "test": unique_items[n - n_test :],
    }

    for split, items in split_groups.items():
        for i, (text, sign) in enumerate(items):
            global_seen_norm.add(normalize_merchant(text))
            family_suffix = f"_{sign}" if sign else ""
            # each row gets its OWN family (not a shared per-category
            # bucket) -- a shared family split across train/val/test would
            # violate the trainer's family-integrity check, same as it
            # would for hand-curated families.
            bulk_rows.append({
                "text": text,
                "label": label,
                "merchant_family": f"bulk_{label.lower()}{family_suffix}_{split}_{i}",
                "split": split,
            })

# --- Write combined corpus: same 4 columns as your original schema ---
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
dataset is preserved only as a suffix on merchant_family in case you want
to inspect/filter it later -- it is NOT a training column.

Correction from earlier: the trainer's normalizeMerchant() uppercases
text before comparing/training, so casing does NOT survive as a signal
(the FANDUEL CANADA / FanDuel Canada distinction I floated earlier is
moot -- both collapse to the same string). If you want direction as an
actual feature, it needs to survive as a real token, e.g. prepending
"[debit] " / "[credit] " to text at both train and inference time.
""")