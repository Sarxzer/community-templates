#!/usr/bin/env bash
set -euo pipefail

config="${XDG_CONFIG_HOME:-$HOME/.config}/ratune/config.toml"
generated="${XDG_CONFIG_HOME:-$HOME/.config}/ratune/theme.generated.toml"

if [[ ! -f "$config" ]]; then
    echo "Ratune config not found: $config" >&2
    exit 1
fi

if [[ ! -f "$generated" ]]; then
    echo "Generated Noctalia theme not found: $generated" >&2
    exit 1
fi

python3 - "$config" "$generated" <<'PY'
import os
import re
import sys
import tempfile
from pathlib import Path

config = Path(sys.argv[1])
generated = Path(sys.argv[2])

original = config.read_text()
theme = generated.read_text().strip()

if not re.match(r"^\[theme\]\s*$", theme.splitlines()[0]):
    raise SystemExit("Generated file must start with [theme]")

pattern = re.compile(
    r"(?ms)^\[theme\][ \t]*\r?\n.*?"
    r"(?=^\[|\Z)"
)

if pattern.search(original):
    updated = pattern.sub(theme + "\n\n", original, count=1)
else:
    updated = original.rstrip() + "\n\n" + theme + "\n"

fd, temporary = tempfile.mkstemp(
    dir=config.parent, prefix=config.name + "."
)

try:
    with os.fdopen(fd, "w") as f:
        f.write(updated)

    os.chmod(temporary, config.stat().st_mode)
    os.replace(temporary, config)
except BaseException:
    try:
        os.unlink(temporary)
    except FileNotFoundError:
        pass
    raise
PY
