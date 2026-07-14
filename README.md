# Grok Build CLI Upload Block

> **[繁體中文說明 / Chinese Instructions](#繁體中文說明)**

**Stop Grok Build CLI from silently uploading your code, conversations, and terminal output to xAI's servers.**

---

## The Problem

Grok Build CLI (v0.2.93+) silently packages your entire coding session and queues it for upload to Google Cloud Storage — **no opt-in, no notification, enabled by default**.

### What gets uploaded

| Data | Description |
|---|---|
| `chat_history.jsonl` | Your complete conversation — every prompt you typed, every model reply |
| `terminal/*.log` | Full output of every terminal command you ran |
| `prompt_context.json` | Your AGENTS.md files, persona settings, working directory path |
| `system_prompt.txt` | Your full system prompt |
| `hunk_records.jsonl` | All code diffs (your actual code changes) |
| `summary.json` | Git remote URLs, commit hashes, working directory paths |

### How we know

A binary string scan of `grok.exe` (135 MB) reveals:

| Embedded String | What It Does |
|---|---|
| `grok-code-session-traces` | GCS bucket — the upload destination |
| `xai-data-collector` | Rust crate — the data collector module |
| `storage.googleapis.com` | Google Cloud Storage — direct upload endpoint |
| `codebase_upload` | Mechanism to upload your entire codebase |
| `upload_queue` | Local staging directory for files waiting to be sent |
| `file_access_tracker` | Tracks which files you accessed |

The `upload_queue/` directory can accumulate **thousands of files (1+ GB)** in a single day. Even toggling off "Improve the model" in the UI may not stop it — the server-side flag can still return `true`.

> Source: [cereblab/grok-build-cli-wire-analysis](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547) (2025-07-10)

---

## How to Use

**Download ONE file for your platform, run it, choose option 1. Done.**

| Platform | File | How to Run |
|---|---|---|
| **Windows** | [`block_grok_upload.bat`](block_grok_upload.bat) | Double-click, or open Command Prompt and run it |
| **macOS / Linux** | [`block_grok_upload.sh`](block_grok_upload.sh) | `chmod +x block_grok_upload.sh && ./block_grok_upload.sh` |

No Python, no Node.js, no dependencies. Just your OS's built-in shell.

> If you have Python installed, you can also use [`block_grok_upload.py`](block_grok_upload.py) — it works on all platforms.

### Review before running (recommended)

Right-click the file → Open with Notepad / TextEdit / any text editor. Every step is commented so you can see exactly what it does.

### Options

```
  1 — Block uploads  (apply all protection ← pick this)
  2 — Check status   (verify protection is working)
  q — Quit
```

---

## What Does Option 1 Do?

| Step | What It Does | Scope |
|---|---|---|
| **Environment variables** | Sets `GROK_TELEMETRY_ENABLED=0` and `GROK_TELEMETRY_TRACE_UPLOAD=0` permanently | Survives reboot |
| **config.toml** | Adds `disable_codebase_upload = true`, `trace_upload = false`, `mixpanel_enabled = false` to `~/.grok/config.toml` | App-level |
| **Queue cleanup** | Deletes all pending upload files from `~/.grok/upload_queue/` | One-time cleanup |

Safe to run multiple times. Backs up your config before modifying. Won't break Grok's chat functionality.

---

## Known Limitations

| Limitation | Details |
|---|---|
| Config may be ignored | xAI's binary may not fully honor `config.toml` settings — the server can override |
| Future versions may change | xAI may alter upload paths or mechanisms in updates |
| Event tracking not blocked | `grok.com/_data/v1/events` is left open to avoid breaking authentication |

---

## References

| Source | Link |
|---|---|
| Original discovery | [cereblab/grok-build-cli-wire-analysis](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547) |
| Community fix | config.toml + env vars (by [tomholford](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547)) |
| xAI Privacy Policy | https://x.ai/legal/privacy-policy |
| xAI Terms of Service | https://x.ai/legal/terms-of-service |

---

## License

MIT — see [LICENSE](LICENSE).

---

---

# 繁體中文說明

## 這是什麼問題？

Grok Build CLI（xAI 的 AI 程式助手，類似 Claude Code / Cursor）會在你**完全不知情**的情況下，把你的工作階段打包上傳到 xAI 的伺服器。

### 被上傳的內容

| 資料 | 說明 |
|---|---|
| `chat_history.jsonl` | 你的**完整對話紀錄** — 你打的每一句話、AI 的每一個回覆 |
| `terminal/*.log` | 你執行的**每一條終端指令的完整輸出** |
| `prompt_context.json` | 你的 AGENTS.md 設定檔、角色設定、工作目錄路徑 |
| `system_prompt.txt` | 你的完整系統提示詞 |
| `hunk_records.jsonl` | 所有程式碼差異（你改的每一行 code） |
| `summary.json` | Git remote URL、commit hash、工作目錄路徑 |

沒有任何提示或同意選項，預設就是全開的。`upload_queue/` 資料夾一天內可以累積**數千個檔案、超過 1 GB**。

> 來源：[cereblab 的原始分析報告](https://gist.github.com/cereblab/dc9a40bc26120f4540e4e09b75ffb547)

---

## 怎麼用？

**下載你平台對應的檔案，執行它，選 1。結束。**

| 平台 | 檔案 | 怎麼跑 |
|---|---|---|
| **Windows** | [`block_grok_upload.bat`](block_grok_upload.bat) | 雙擊執行 |
| **macOS / Linux** | [`block_grok_upload.sh`](block_grok_upload.sh) | `chmod +x block_grok_upload.sh && ./block_grok_upload.sh` |

不需要 Python、不需要 Node.js、不需要裝任何東西。

> 如果你有裝 Python，也可以用 [`block_grok_upload.py`](block_grok_upload.py)，三個平台都能跑。

### 先看內容再執行（建議）

右鍵點擊檔案 → 用記事本打開，確認程式碼在做什麼。所有步驟都有清楚的註解。

### 選項

```
  1 — 阻擋上傳（套用所有防護 ← 選這個）
  2 — 檢查狀態（驗證防護是否生效）
  q — 離開
```

---

## 選 1 之後做了什麼？

| 步驟 | 做了什麼 | 範圍 |
|---|---|---|
| **環境變數** | 永久設定 `GROK_TELEMETRY_ENABLED=0`、`GROK_TELEMETRY_TRACE_UPLOAD=0` | 重開機仍有效 |
| **config.toml** | 寫入 `disable_codebase_upload = true`、`trace_upload = false`、`mixpanel_enabled = false` | 應用程式層級 |
| **清理上傳佇列** | 刪除 `~/.grok/upload_queue/` 裡所有待上傳的檔案 | 一次性清理 |

可以重複執行，不會壞掉。修改前會自動備份 config。Grok 的聊天功能不受影響。

---

## 已知限制

| 限制 | 說明 |
|---|---|
| 設定可能被忽略 | xAI 的程式不保證完全遵守 config.toml — 伺服器端可以覆蓋 |
| 未來版本可能改變 | xAI 可能在更新中改變上傳路徑或機制 |
| 事件追蹤未封鎖 | `grok.com/_data/v1/events` 沒有封鎖，避免影響登入認證 |
