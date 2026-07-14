@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Grok Build CLI - Upload Block Tool

set "GROK_HOME=%USERPROFILE%\.grok"
set "CONFIG=!GROK_HOME!\config.toml"
set "QUEUE=!GROK_HOME!\upload_queue"

echo.
echo   ========================================================
echo     Grok Build CLI -- Upload Block Tool (Windows)
echo   ========================================================
echo.
echo   Grok Build CLI silently uploads your code, conversations,
echo   and terminal output to xAI servers. This tool stops it.

REM --- Scan upload queue so the user sees what's pending ---
echo.
set "qcount=0"
if exist "!QUEUE!" for /f %%a in ('dir /a-d /s /b "!QUEUE!" 2^>nul ^| find /c /v ""') do set "qcount=%%a"
if !qcount! GTR 0 (
    echo   !! WARNING: Found !qcount! files waiting to upload to xAI !!
    echo   They contain your chat history, terminal output, and code.
) else (
    echo   Upload queue: empty (no pending uploads found)
)

echo.
echo   Options:
echo     1 -- Block uploads  (apply all protection)
echo     2 -- Check status   (verify protection is working)
echo     q -- Quit
echo.

set /p "choice=  Choose [1/2/q]: "

if "!choice!"=="1" goto BLOCK
if "!choice!"=="2" goto CHECK
if "!choice!"=="q" goto END
if "!choice!"=="" goto END
echo   Unknown option.
goto END

:BLOCK
echo.
echo   Applying upload protection...
echo   ========================================================

REM --- Step 1: Environment variables (permanent, user-level) ---
echo.
echo   [Step 1/3] Setting environment variables...
setx GROK_TELEMETRY_ENABLED 0 >nul 2>&1
set "GROK_TELEMETRY_ENABLED=0"
echo     OK: GROK_TELEMETRY_ENABLED = 0

setx GROK_TELEMETRY_TRACE_UPLOAD 0 >nul 2>&1
set "GROK_TELEMETRY_TRACE_UPLOAD=0"
echo     OK: GROK_TELEMETRY_TRACE_UPLOAD = 0

REM --- Step 2: config.toml ---
echo.
echo   [Step 2/3] Updating config.toml...

if not exist "!GROK_HOME!" mkdir "!GROK_HOME!"

if exist "!CONFIG!" (
    findstr /c:"disable_codebase_upload" "!CONFIG!" >nul 2>&1
    if not errorlevel 1 (
        echo     OK: config.toml already has upload block settings
    ) else (
        copy "!CONFIG!" "!CONFIG!.bak" >nul 2>&1
        echo.>> "!CONFIG!"
        echo [features]>> "!CONFIG!"
        echo telemetry = false>> "!CONFIG!"
        echo.>> "!CONFIG!"
        echo [telemetry]>> "!CONFIG!"
        echo trace_upload = false>> "!CONFIG!"
        echo mixpanel_enabled = false>> "!CONFIG!"
        echo.>> "!CONFIG!"
        echo [harness]>> "!CONFIG!"
        echo disable_codebase_upload = true>> "!CONFIG!"
        echo     OK: Appended settings to config.toml
    )
) else (
    echo [features]> "!CONFIG!"
    echo telemetry = false>> "!CONFIG!"
    echo.>> "!CONFIG!"
    echo [telemetry]>> "!CONFIG!"
    echo trace_upload = false>> "!CONFIG!"
    echo mixpanel_enabled = false>> "!CONFIG!"
    echo.>> "!CONFIG!"
    echo [harness]>> "!CONFIG!"
    echo disable_codebase_upload = true>> "!CONFIG!"
    echo     OK: Created config.toml
)

REM --- Step 3: Clean upload queue ---
echo.
echo   [Step 3/3] Cleaning upload queue...

if exist "!QUEUE!" (
    set "fcount=0"
    for /f %%a in ('dir /a-d /s /b "!QUEUE!" 2^>nul ^| find /c /v ""') do set "fcount=%%a"
    if !fcount! GTR 0 (
        rd /s /q "!QUEUE!" 2>nul
        mkdir "!QUEUE!" 2>nul
        echo     OK: Deleted !fcount! pending upload files
    ) else (
        echo     OK: upload_queue/ is already empty
    )
) else (
    echo     OK: No upload_queue/ found
)

echo.
echo   ========================================================
echo     Done! Upload protection applied.
echo   ========================================================
echo.
goto END

:CHECK
echo.
echo   Checking protection status...
echo.

set "pass=0"
set "fail=0"

echo   Environment Variables

reg query "HKCU\Environment" /v GROK_TELEMETRY_ENABLED >nul 2>&1
if not errorlevel 1 (
    echo     PASS: GROK_TELEMETRY_ENABLED
    set /a pass+=1
) else (
    echo     FAIL: GROK_TELEMETRY_ENABLED not set
    set /a fail+=1
)

reg query "HKCU\Environment" /v GROK_TELEMETRY_TRACE_UPLOAD >nul 2>&1
if not errorlevel 1 (
    echo     PASS: GROK_TELEMETRY_TRACE_UPLOAD
    set /a pass+=1
) else (
    echo     FAIL: GROK_TELEMETRY_TRACE_UPLOAD not set
    set /a fail+=1
)

echo.
echo   config.toml

if exist "!CONFIG!" (
    findstr /c:"disable_codebase_upload" "!CONFIG!" >nul 2>&1
    if not errorlevel 1 (
        echo     PASS: disable_codebase_upload
        set /a pass+=1
    ) else (
        echo     FAIL: disable_codebase_upload not found
        set /a fail+=1
    )

    findstr /c:"trace_upload" "!CONFIG!" >nul 2>&1
    if not errorlevel 1 (
        echo     PASS: trace_upload
        set /a pass+=1
    ) else (
        echo     FAIL: trace_upload not found
        set /a fail+=1
    )

    findstr /c:"mixpanel_enabled" "!CONFIG!" >nul 2>&1
    if not errorlevel 1 (
        echo     PASS: mixpanel_enabled
        set /a pass+=1
    ) else (
        echo     FAIL: mixpanel_enabled not found
        set /a fail+=1
    )
) else (
    echo     FAIL: config.toml not found
    set /a fail+=3
)

echo.
echo   Upload Queue

if exist "!QUEUE!" (
    dir /a-d /s /b "!QUEUE!" >nul 2>&1
    if errorlevel 1 (
        echo     PASS: upload_queue/ is empty
        set /a pass+=1
    ) else (
        echo     FAIL: upload_queue/ has pending files
        set /a fail+=1
    )
) else (
    echo     PASS: no upload_queue/ directory
    set /a pass+=1
)

echo.
echo   ========================================
if !fail!==0 (
    echo     ALL CHECKS PASSED
) else (
    echo     !fail! FAILED -- run option 1 to fix
)
echo   ========================================
echo.

:END
endlocal
pause
