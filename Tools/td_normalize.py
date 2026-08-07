"""
Faithful Python port of the Swift trainer's normalizeMerchant(_:) function,
used ONLY as the key for checking uniqueness/collisions before writing the
CSV. The trainer does this normalization itself at train/predict time --
we're not trying to change what text looks like, just predict what it'll
collapse to so we don't hand it two rows that collide.
"""
import re

def normalize_merchant(raw: str) -> str:
    value = raw.strip().strip('"').upper()

    # strip FIRST occurrence anywhere of optional-space + # + digits
    value = re.sub(r"\s*#\d+", "", value, count=1)

    # strip a fixed suffix if present (checks all four, same as Swift loop)
    for suffix in ["_M", "_V", "_T", "_INV"]:
        if value.endswith(suffix):
            value = value[: -len(suffix)]

    # strip trailing "123.45"
    value = re.sub(r"\s+\d+\.\d+$", "", value)
    # strip trailing "123"
    value = re.sub(r"\s+\d+$", "", value)

    while "  " in value:
        value = value.replace("  ", " ")

    return value.strip()