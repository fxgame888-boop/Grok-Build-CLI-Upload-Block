"""
Grok Build CLI — Upload Block Tool
====================================

Grok Build CLI (v0.2.93+) silently uploads your coding sessions to xAI's servers:
full chat history, terminal outputs, code diffs, file access logs — without consent.

This tool blocks that behavior. Run it, pick an option, done.

    Windows:  python block_grok_upload.py
    Mac/Linux: python3 block_grok_upload.py

Right-click this file and open with any text editor to review the code.
No external dependencies required — just Python 3.6+.

Source: https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547
"""

import os
import sys
import shutil
import platform
import subprocess
import re
from pathlib import Path

# ─────────────────────────────────────────────────────────────
# Where Grok stores its data
# ─────────────────────────────────────────────────────────────
GROK_HOME = Path.home() / ".grok"
CONFIG_PATH = GROK_HOME / "config.toml"
QUEUE_PATH = GROK_HOME / "upload_queue"
IS_WINDOWS = platform.system() == "Windows"

# The settings we add to config.toml to disable uploads
CONFIG_BLOCK = """
[features]
telemetry = false

[telemetry]
trace_upload = false
mixpanel_enabled = false

[harness]
disable_codebase_upload = true
"""

# Environment variables that tell Grok to stop uploading
ENV_VARS = {
    "GROK_TELEMETRY_ENABLED": "0",
    "GROK_TELEMETRY_TRACE_UPLOAD": "0",
}


def green(text):
    return f"\033[32m{text}\033[0m"

def yellow(text):
    return f"\033[33m{text}\033[0m"

def red(text):
    return f"\033[31m{text}\033[0m"

def cyan(text):
    return f"\033[36m{text}\033[0m"

def gray(text):
    return f"\033[90m{text}\033[0m"


# =============================================================
# 1. BLOCK — Apply all protection
# =============================================================

def apply_env_vars():
    """Set environment variables to disable telemetry."""
    print(f"\n  {yellow('[Step 1/3]')} Setting environment variables...")

    for key, value in ENV_VARS.items():
        os.environ[key] = value

        if IS_WINDOWS:
            try:
                subprocess.run(
                    ["setx", key, value],
                    capture_output=True, check=True
                )
                print(f"    {green('OK')}: {key} = {value} (permanent)")
            except Exception as e:
                print(f"    {red('WARN')}: Could not set {key}: {e}")
        else:
            profile = _detect_shell_profile()
            if profile and profile.exists():
                content = profile.read_text()
                export_line = f"export {key}={value}"
                if key not in content:
                    with open(profile, "a") as f:
                        f.write(f"\n{export_line}\n")
                    print(f"    {green('OK')}: {key} = {value} (added to {profile.name})")
                else:
                    print(f"    {green('OK')}: {key} already in {profile.name}")
            else:
                print(f"    {yellow('WARN')}: Add manually: export {key}={value}")


def apply_config_toml():
    """Add settings to config.toml to disable uploads."""
    print(f"\n  {yellow('[Step 2/3]')} Updating config.toml...")

    GROK_HOME.mkdir(parents=True, exist_ok=True)

    if CONFIG_PATH.exists():
        backup = CONFIG_PATH.with_suffix(f".toml.bak")
        shutil.copy2(CONFIG_PATH, backup)
        print(f"    {gray(f'Backup: {backup.name}')}")

        content = CONFIG_PATH.read_text(encoding="utf-8")

        for pattern in [
            r"(?m)^\s*telemetry\s*=\s*.*$",
            r"(?m)^\s*trace_upload\s*=\s*.*$",
            r"(?m)^\s*mixpanel_enabled\s*=\s*.*$",
            r"(?m)^\s*disable_codebase_upload\s*=\s*.*$",
        ]:
            content = re.sub(pattern, "", content)

        for section in ["features", "telemetry", "harness"]:
            content = re.sub(
                rf"(?m)^\s*\[{section}\]\s*\n(?=\s*\[|\s*$)", "", content
            )

        content = content.rstrip() + "\n" + CONFIG_BLOCK.strip() + "\n"
        CONFIG_PATH.write_text(content, encoding="utf-8")
        print(f"    {green('OK')}: Merged settings into config.toml")
    else:
        CONFIG_PATH.write_text(CONFIG_BLOCK.strip() + "\n", encoding="utf-8")
        print(f"    {green('OK')}: Created config.toml")


def clean_upload_queue():
    """Delete all files in upload_queue/ to prevent pending uploads."""
    print(f"\n  {yellow('[Step 3/3]')} Cleaning upload queue...")

    if not QUEUE_PATH.exists():
        print(f"    {green('OK')}: No upload_queue/ found (nothing to clean)")
        return 0

    files = list(QUEUE_PATH.rglob("*"))
    file_count = sum(1 for f in files if f.is_file())
    total_bytes = sum(f.stat().st_size for f in files if f.is_file())

    if file_count == 0:
        print(f"    {green('OK')}: upload_queue/ is already empty")
        return 0

    size_mb = round(total_bytes / (1024 * 1024), 1)

    for item in QUEUE_PATH.iterdir():
        if item.is_file():
            item.unlink()
        elif item.is_dir():
            shutil.rmtree(item)

    print(f"    {green('OK')}: Deleted {file_count} files ({size_mb} MB)")
    return file_count


def do_block():
    """Apply all protection."""
    print(f"\n  {cyan('='*56)}")
    print(f"  {cyan('  Applying upload protection...')}")
    print(f"  {cyan('='*56)}")

    apply_env_vars()
    apply_config_toml()
    clean_upload_queue()

    print(f"\n  {cyan('='*56)}")
    print(f"  {green('  Done! Upload protection applied.')}")
    if not IS_WINDOWS:
        print(f"  {gray('  Restart your terminal for env vars to take effect.')}")
    print(f"  {cyan('='*56)}\n")


# =============================================================
# 2. CHECK — Verify protection is in place
# =============================================================

def do_check():
    """Check all protection layers and report status."""
    print(f"\n  {cyan('Checking protection status...')}\n")
    passed = 0
    failed = 0

    # --- Env vars ---
    print(f"  {yellow('Environment Variables')}")
    for key, expected in ENV_VARS.items():
        val = os.environ.get(key)
        if IS_WINDOWS:
            try:
                result = subprocess.run(
                    ["reg", "query", "HKCU\\Environment", "/v", key],
                    capture_output=True, text=True
                )
                reg_val = None
                if result.returncode == 0:
                    for line in result.stdout.splitlines():
                        if key in line:
                            parts = line.strip().split()
                            reg_val = parts[-1] if parts else None
                if reg_val == expected:
                    print(f"    {green('PASS')}: {key} = {expected}")
                    passed += 1
                else:
                    print(f"    {red('FAIL')}: {key} not set (expected '{expected}')")
                    failed += 1
            except Exception:
                if val == expected:
                    print(f"    {green('PASS')}: {key} = {expected} (session only)")
                    passed += 1
                else:
                    print(f"    {red('FAIL')}: {key} not set")
                    failed += 1
        else:
            profile = _detect_shell_profile()
            in_profile = False
            if profile and profile.exists():
                in_profile = key in profile.read_text()
            if val == expected or in_profile:
                print(f"    {green('PASS')}: {key} = {expected}")
                passed += 1
            else:
                print(f"    {red('FAIL')}: {key} not set")
                failed += 1

    # --- config.toml ---
    print(f"\n  {yellow('config.toml')}")
    if CONFIG_PATH.exists():
        content = CONFIG_PATH.read_text(encoding="utf-8")
        checks = [
            (r"disable_codebase_upload\s*=\s*true", "disable_codebase_upload = true"),
            (r"trace_upload\s*=\s*false",           "trace_upload = false"),
            (r"mixpanel_enabled\s*=\s*false",        "mixpanel_enabled = false"),
        ]
        for pattern, label in checks:
            if re.search(pattern, content):
                print(f"    {green('PASS')}: {label}")
                passed += 1
            else:
                print(f"    {red('FAIL')}: {label} not found")
                failed += 1
    else:
        print(f"    {red('FAIL')}: config.toml not found")
        failed += 3

    # --- Upload queue ---
    print(f"\n  {yellow('Upload Queue')}")
    if QUEUE_PATH.exists():
        file_count = sum(1 for _ in QUEUE_PATH.rglob("*") if _.is_file())
        if file_count == 0:
            print(f"    {green('PASS')}: upload_queue/ is empty")
            passed += 1
        else:
            print(f"    {red('FAIL')}: upload_queue/ has {file_count} pending files")
            failed += 1
    else:
        print(f"    {green('PASS')}: no upload_queue/ directory")
        passed += 1

    # --- Summary ---
    total = passed + failed
    print(f"\n  {'='*40}")
    if failed == 0:
        print(f"  {green(f'ALL CHECKS PASSED ({passed}/{total})')}")
    else:
        print(f"  {red(f'{failed} FAILED')} / {passed} passed (total {total})")
        print(f"  Run option 1 to fix.")
    print(f"  {'='*40}\n")


# =============================================================
# Utilities
# =============================================================

def _detect_shell_profile():
    """Find the user's shell profile file (macOS/Linux)."""
    shell = os.environ.get("SHELL", "")
    home = Path.home()
    if "zsh" in shell:
        return home / ".zshrc"
    elif "bash" in shell:
        profile = home / ".bash_profile"
        return profile if profile.exists() else home / ".bashrc"
    return None


# =============================================================
# Main menu
# =============================================================

def scan_upload_queue():
    """Scan upload_queue/ and show status — always displayed."""
    if QUEUE_PATH.exists():
        files = [f for f in QUEUE_PATH.rglob("*") if f.is_file()]
        if files:
            total_bytes = sum(f.stat().st_size for f in files)
            size_mb = round(total_bytes / (1024 * 1024), 1)
            print(f"\n  {red(f'!! WARNING: Found {len(files)} files ({size_mb} MB) waiting to upload to xAI !!')}")
            print("  They contain your chat history, terminal output, and code.")
            return
    print(f"\n  Upload queue: empty (no pending uploads found)")


def main():
    print("")
    print(f"  {cyan('='*56)}")
    print(f"  {cyan('  Grok Build CLI — Upload Block Tool')}")
    print(f"  {cyan('='*56)}")
    print("")
    print("  Grok Build CLI silently uploads your code, conversations,")
    print("  and terminal output to xAI servers. This tool stops it.")

    scan_upload_queue()

    print("")
    print(f"  {gray(f'Grok home: {GROK_HOME}')}")
    print(f"  {gray(f'Platform:  {platform.system()}')}")
    print("")
    print("  Options:")
    print(f"    {cyan('1')} — Block uploads  (apply all protection)")
    print(f"    {cyan('2')} — Check status   (verify protection is working)")
    print(f"    {cyan('q')} — Quit")
    print("")

    choice = input("  Choose [1/2/q]: ").strip().lower()

    if choice == "1":
        do_block()
    elif choice == "2":
        do_check()
    elif choice in ("q", ""):
        print("  Bye.\n")
    else:
        print(f"  {yellow('Unknown option.')} Choose 1, 2, or q.\n")


if __name__ == "__main__":
    main()
