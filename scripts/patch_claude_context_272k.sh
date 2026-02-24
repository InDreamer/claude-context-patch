#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<"USAGE"
Usage:
  ./patch_claude_context_272k.sh [path-to-claude-binary-or-cli.js]

Default target is the current `claude` on PATH.
The script creates a timestamped backup before patching.
USAGE
  exit 0
fi

TARGET_INPUT="${1:-}"
if [[ -z "$TARGET_INPUT" ]]; then
  TARGET_INPUT="$(command -v claude || true)"
fi

if [[ -z "$TARGET_INPUT" ]]; then
  echo "[x] Cannot find claude. Pass a target path explicitly." >&2
  exit 1
fi

TARGET="$(realpath "$TARGET_INPUT")"
if [[ ! -f "$TARGET" ]]; then
  echo "[x] Target does not exist: $TARGET" >&2
  exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${TARGET}.bak.${STAMP}"
cp -p "$TARGET" "$BACKUP"

echo "[*] Target : $TARGET"
echo "[*] Backup : $BACKUP"

PATCH_OUT="$(python3 - "$TARGET" <<"PY"
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
raw = path.read_bytes()

is_js = raw.startswith(b"#!/usr/bin/env node") or path.suffix == ".js"
mode = "js" if is_js else "binary"
enc = "utf-8" if is_js else "latin1"
text = raw.decode(enc, errors="ignore" if is_js else "strict")
orig = text

changes = []

def rep_exact(old: str, new: str, label: str, equal_len: bool = False) -> int:
    global text
    c = text.count(old)
    if c == 0:
        return 0
    if equal_len and len(old) != len(new):
        raise SystemExit(f"Length mismatch for {label}: {len(old)} != {len(new)}")
    text = text.replace(old, new)
    changes.append((label, c))
    return c

# ---------------------------
# Newer JS build patterns
# ---------------------------
rep_exact(
    "var puq=200000,jR6=20000,duq=32000,cuq=31999;",
    "var puq=272000,jR6=20000,duq=32000,cuq=31999;",
    "set puq=272000",
)

# Some builds gate special models to 1e6; force all models to shared puq.
text, n = re.subn(
    r"function IG\(A,q\)\{if\([^{}]*?\)return 1e6;return puq\}",
    "function IG(A,q){return puq}",
    text,
)
if n:
    changes.append(("force IG() to return puq", n))

# Canonical effective window and threshold logic for newer builds.
text, n = re.subn(
    r"function N91\(A\)\{[^{}]*\}",
    "function N91(A){return Math.floor(IG(A,iP())*95/100)}",
    text,
)
if n:
    changes.append(("set effective window to 95%", n))

text, n = re.subn(
    r"function lQ1\(A\)\{let q=N91\(A\),K=.*?return K\}",
    "function lQ1(A){let q=N91(A),K=Math.floor(IG(A,iP())*90/100),Y=process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE;if(Y){let z=parseFloat(Y);if(!isNaN(z)&&z>0&&z<=100){let w=Math.floor(q*(z/100));return Math.min(w,K)}}return K}",
    text,
)
if n:
    changes.append(("set autocompact threshold to 90%", n))

# ---------------------------
# Older packed/native build patterns
# ---------------------------
rep_exact(
    "var r5D=200000,xiA=20000,o5D=32000,s5D=64000;",
    "var r5D=272000,xiA=20000,o5D=32000,s5D=64000;",
    "set r5D=272000",
)

# Claude Code 2.1.49 native bundle constants.
rep_exact(
    "var KC0=200000,gnA=20000,NC0=32000,IC0=64000;",
    "var KC0=272000,gnA=20000,NC0=32000,IC0=64000;",
    "set KC0=272000",
)
rep_exact(
    "var Ps7=20000,UVA=13000,ys7=20000,bs7=20000,FVA=3000;",
    "var Ps7=13600,UVA=13600,ys7=20000,bs7=20000,FVA=3000;",
    "set Ps7/UVA=13600",
)
rep_exact(
    "function $h(T,R){if(rk(T)||R?.includes(BfT)&&ZC0(T))return 1e6;return KC0}",
    "function $h(T,R){if(rk(T)||R?.includes(BfT)&&ZC0(T))return KC0;return KC0}",
    "disable 1m override in $h()",
    equal_len=True,
)

# Claude Code 2.1.50 native bundle constants.
rep_exact(
    "var _WD=200000,gaA=20000,BWD=32000,DWD=64000;",
    "var _WD=272000,gaA=20000,BWD=32000,DWD=64000;",
    "set _WD=272000",
)
rep_exact(
    "var Ee7=20000,XwA=13000,Le7=20000,Ke7=20000,EwA=3000;",
    "var Ee7=13600,XwA=13600,Le7=20000,Ke7=20000,EwA=3000;",
    "set Ee7/XwA=13600",
)
rep_exact(
    "function Jh(T,R){if(tk(T)||R?.includes(XfT)&&$WD(T))return 1e6;return _WD}",
    "function Jh(T,R){if(tk(T)||R?.includes(XfT)&&$WD(T))return _WD;return _WD}",
    "disable 1m override in Jh()",
    equal_len=True,
)

old_rx = "function RX(T,R){if(gk(T)||R?.includes(gZT)&&t5D(T))return 1e6;return r5D}"
new_rx_len_safe = "function RX(T,R){if(gk(T)||R?.includes(gZT)&&t5D(T))return r5D;return r5D}"

old_f = "function F$T(T){let R=Math.min(UkA(T),a38);return RX(T,eW())-R}"
new_f_len_safe = "function F$T(T){let R=Math.floor(RX(T,eW())*95/100);return R  }"

old_g = "function GcT(T){let R=F$T(T),A=R-fkA,_=process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE;if(_){let B=parseFloat(_);if(!isNaN(B)&&B>0&&B<=100){let D=Math.floor(R*(B/100));return Math.min(D,A)}}return A}"
new_g_len_safe = "function GcT(T){let R=F$T(T),A=R/19*18,_=process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE;if(_){let B=parseFloat(_);if(B>0&&B<=100){let D=Math.floor(R*(B/100));return Math.min(D,A)}}return A         }"

rx_hits = 0
f_hits = 0
g_hits = 0
if mode == "binary":
    # For native Mach-O, keep byte length stable to avoid binary corruption.
    rx_hits = rep_exact(old_rx, new_rx_len_safe, "force RX() to shared window", equal_len=True)
    f_hits = rep_exact(old_f, new_f_len_safe, "set F$T() to 95%", equal_len=True)
    g_hits = rep_exact(old_g, new_g_len_safe, "set GcT() to 90%", equal_len=True)
else:
    rx_hits = rep_exact(old_rx, "function RX(T,R){return r5D}", "force RX() to shared window")
    f_hits = rep_exact(old_f, "function F$T(T){return Math.floor(RX(T,eW())*95/100)}", "set F$T() to 95%")
    g_hits = rep_exact(
        old_g,
        "function GcT(T){let R=F$T(T),A=Math.floor(RX(T,eW())*90/100),_=process.env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE;if(_){let B=parseFloat(_);if(!isNaN(B)&&B>0&&B<=100){let D=Math.floor(R*(B/100));return Math.min(D,A)}}return A}",
        "set GcT() to 90%",
    )

if text == orig:
    print(f"[=] No patch needed ({mode}). Already patched or unknown build.")
    sys.exit(0)

out = text.encode(enc)
if mode == "binary" and len(out) != len(raw):
    raise SystemExit(
        f"Refusing to write binary with changed size: {len(raw)} -> {len(out)}"
    )

path.write_bytes(out)
print(f"[+] Patched ({mode})")
for label, count in changes:
    print(f"    - {label}: {count} hit(s)")

# Sanity checks
checks = []
checks.append(("272000 constant", ("272000" in text)))
if "function N91(A)" in text:
    checks.append(("effective 95%", "function N91(A){return Math.floor(IG(A,iP())*95/100)}" in text))
if "function lQ1(A)" in text:
    checks.append(("threshold 90%", "Math.floor(IG(A,iP())*90/100)" in text or "A=R/19*18" in text))
if f_hits:
    checks.append(("effective 95% (legacy)", "*95/100" in text))
if g_hits:
    checks.append(("threshold 90% (legacy)", "A=R/19*18" in text or "*90/100" in text))
if "function g8T(T)" in text and "function XcT(T)" in text:
    checks.append(
        (
            "effective/threshold constants (2.1.49 native)",
            "var Ps7=13600,UVA=13600,ys7=20000,bs7=20000,FVA=3000;" in text,
        )
    )
if "function $h(T,R)" in text:
    checks.append(
        (
            "disable 1m override (2.1.49 native)",
            "function $h(T,R){if(rk(T)||R?.includes(BfT)&&ZC0(T))return KC0;return KC0}" in text,
        )
    )
if "function R$T(T)" in text and "function xcT(T)" in text:
    checks.append(
        (
            "effective/threshold constants (2.1.50 native)",
            "var Ee7=13600,XwA=13600,Le7=20000,Ke7=20000,EwA=3000;" in text,
        )
    )
if "function Jh(T,R)" in text:
    checks.append(
        (
            "disable 1m override (2.1.50 native)",
            "function Jh(T,R){if(tk(T)||R?.includes(XfT)&&$WD(T))return _WD;return _WD}" in text,
        )
    )

failed = [name for name, ok in checks if not ok]
if failed:
    raise SystemExit("Sanity checks failed: " + ", ".join(failed))
print("[+] Sanity checks passed")
PY
)"

echo "$PATCH_OUT"

if [[ "$PATCH_OUT" == *"[+] Patched (binary)"* ]]; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if ! command -v codesign >/dev/null 2>&1; then
      echo "[x] codesign not found; patched Mach-O may be killed by macOS." >&2
      exit 1
    fi
    codesign --force --sign - "$TARGET"
    echo "[+] Re-signed binary (ad-hoc)"
  fi
fi

echo "[*] Done."
echo "[*] Rollback: cp -f \"$BACKUP\" \"$TARGET\""
