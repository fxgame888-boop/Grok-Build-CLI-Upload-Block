#!/usr/bin/env bash
#
# Grok Build CLI — Upload Block Tool (macOS / Linux)
#
# Grok Build CLI (v0.2.93+) silently uploads your coding sessions to xAI's servers.
# This script blocks that behavior. No dependencies required.
#
# Usage: chmod +x block_grok_upload.sh && ./block_grok_upload.sh
#

GROK_HOME="$HOME/.grok"
CONFIG="$GROK_HOME/config.toml"
QUEUE="$GROK_HOME/upload_queue"

G='\033[32m'  # green
Y='\033[33m'  # yellow
R='\033[31m'  # red
C='\033[36m'  # cyan
N='\033[0m'   # reset

echo ""
echo -e "  ${C}========================================================${N}"
echo -e "  ${C}  Grok Build CLI — Upload Block Tool (macOS / Linux)${N}"
echo -e "  ${C}========================================================${N}"
echo ""
echo "  Grok Build CLI silently uploads your code, conversations,"
echo "  and terminal output to xAI servers. This tool stops it."

# --- Scan upload queue so the user sees what's pending ---
echo ""
qcount=0
if [ -d "$QUEUE" ]; then
    qcount=$(find "$QUEUE" -type f 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$qcount" -gt 0 ] 2>/dev/null; then
    qsize=$(du -sh "$QUEUE" 2>/dev/null | cut -f1)
    echo -e "  ${R}!! WARNING: Found $qcount files ($qsize) waiting to upload to xAI !!${N}"
    echo "  They contain your chat history, terminal output, and code."
else
    echo "  Upload queue: empty (no pending uploads found)"
fi

echo ""
echo "  Options:"
echo -e "    ${C}1${N} — Block uploads  (apply all protection)"
echo -e "    ${C}2${N} — Check status   (verify protection is working)"
echo -e "    ${C}q${N} — Quit"
echo ""
read -rp "  Choose [1/2/q]: " choice

# ─────────────────────────────────────────────────────────────
# Detect shell profile
# ─────────────────────────────────────────────────────────────
detect_profile() {
    if [ -n "$ZSH_VERSION" ] || echo "$SHELL" | grep -q "zsh"; then
        echo "$HOME/.zshrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        echo "$HOME/.bash_profile"
    else
        echo "$HOME/.bashrc"
    fi
}

# ─────────────────────────────────────────────────────────────
# Option 1: Block
# ─────────────────────────────────────────────────────────────
do_block() {
    echo ""
    echo -e "  ${C}Applying upload protection...${N}"
    echo -e "  ${C}========================================================${N}"

    # Step 1: Environment variables
    echo ""
    echo -e "  ${Y}[Step 1/3]${N} Adding environment variables to shell profile..."

    PROFILE=$(detect_profile)
    for line in 'export GROK_TELEMETRY_ENABLED=0' 'export GROK_TELEMETRY_TRACE_UPLOAD=0'; do
        varname=$(echo "$line" | cut -d= -f1 | sed 's/export //')
        if grep -q "$varname" "$PROFILE" 2>/dev/null; then
            echo -e "    ${G}OK${N}: $varname already in $(basename "$PROFILE")"
        else
            echo "$line" >> "$PROFILE"
            echo -e "    ${G}OK${N}: $varname added to $(basename "$PROFILE")"
        fi
        eval "$line"
    done

    # Step 2: config.toml
    echo ""
    echo -e "  ${Y}[Step 2/3]${N} Updating config.toml..."

    mkdir -p "$GROK_HOME"

    BLOCK='[features]
telemetry = false

[telemetry]
trace_upload = false
mixpanel_enabled = false

[harness]
disable_codebase_upload = true'

    if [ -f "$CONFIG" ]; then
        cp "$CONFIG" "$CONFIG.bak"

        TEMP=$(mktemp)
        # Use [[:space:]] instead of \s for BSD sed (macOS) compatibility
        sed \
            -e '/^[[:space:]]*telemetry[[:space:]]*=[[:space:]]*/d' \
            -e '/^[[:space:]]*trace_upload[[:space:]]*=[[:space:]]*/d' \
            -e '/^[[:space:]]*mixpanel_enabled[[:space:]]*=[[:space:]]*/d' \
            -e '/^[[:space:]]*disable_codebase_upload[[:space:]]*=[[:space:]]*/d' \
            "$CONFIG" > "$TEMP"
        { cat "$TEMP"; echo ""; echo "$BLOCK"; } > "$CONFIG"
        rm -f "$TEMP"
        echo -e "    ${G}OK${N}: Merged settings into config.toml"
    else
        echo "$BLOCK" > "$CONFIG"
        echo -e "    ${G}OK${N}: Created config.toml"
    fi

    # Step 3: Clean upload queue
    echo ""
    echo -e "  ${Y}[Step 3/3]${N} Cleaning upload queue..."

    if [ -d "$QUEUE" ]; then
        count=$(find "$QUEUE" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -gt 0 ] 2>/dev/null; then
            rm -rf "${QUEUE:?}"/*
            echo -e "    ${G}OK${N}: Deleted $count pending files"
        else
            echo -e "    ${G}OK${N}: upload_queue/ is already empty"
        fi
    else
        echo -e "    ${G}OK${N}: No upload_queue/ found"
    fi

    echo ""
    echo -e "  ${C}========================================================${N}"
    echo -e "  ${G}  Done! Upload protection applied.${N}"
    echo "  Restart your terminal for env vars to take effect."
    echo -e "  ${C}========================================================${N}"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# Option 2: Check
# ─────────────────────────────────────────────────────────────
do_check() {
    echo ""
    echo -e "  ${C}Checking protection status...${N}"
    echo ""

    pass=0
    fail=0

    echo -e "  ${Y}Environment Variables${N}"
    PROFILE=$(detect_profile)
    for var in GROK_TELEMETRY_ENABLED GROK_TELEMETRY_TRACE_UPLOAD; do
        found=0
        if grep -q "$var" "$PROFILE" 2>/dev/null; then found=1; fi
        val=$(eval echo "\${$var:-}")
        if [ "$val" = "0" ]; then found=1; fi

        if [ "$found" -eq 1 ]; then
            echo -e "    ${G}PASS${N}: $var"
            pass=$((pass + 1))
        else
            echo -e "    ${R}FAIL${N}: $var not set"
            fail=$((fail + 1))
        fi
    done

    echo ""
    echo -e "  ${Y}config.toml${N}"
    if [ -f "$CONFIG" ]; then
        for key in disable_codebase_upload trace_upload mixpanel_enabled; do
            if grep -q "$key" "$CONFIG" 2>/dev/null; then
                echo -e "    ${G}PASS${N}: $key"
                pass=$((pass + 1))
            else
                echo -e "    ${R}FAIL${N}: $key not found"
                fail=$((fail + 1))
            fi
        done
    else
        echo -e "    ${R}FAIL${N}: config.toml not found"
        fail=$((fail + 3))
    fi

    echo ""
    echo -e "  ${Y}Upload Queue${N}"
    if [ -d "$QUEUE" ]; then
        count=$(find "$QUEUE" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$count" -eq 0 ] 2>/dev/null; then
            echo -e "    ${G}PASS${N}: upload_queue/ is empty"
            pass=$((pass + 1))
        else
            echo -e "    ${R}FAIL${N}: upload_queue/ has $count pending files"
            fail=$((fail + 1))
        fi
    else
        echo -e "    ${G}PASS${N}: no upload_queue/ directory"
        pass=$((pass + 1))
    fi

    echo ""
    echo "  ========================================"
    total=$((pass + fail))
    if [ "$fail" -eq 0 ]; then
        echo -e "  ${G}ALL CHECKS PASSED ($pass/$total)${N}"
    else
        echo -e "  ${R}$fail FAILED${N} — run option 1 to fix"
    fi
    echo "  ========================================"
    echo ""
}

# ─────────────────────────────────────────────────────────────
# Route
# ─────────────────────────────────────────────────────────────
case "$choice" in
    1) do_block ;;
    2) do_check ;;
    q|"") echo "  Bye."; echo "" ;;
    *) echo "  Unknown option. Choose 1, 2, or q." ;;
esac
