@echo off
rem ============================================================================
rem Underwars launcher (self-contained: uses only the repo-local Godot binary).
rem
rem   game.bat            play mode  - greybox map viewer, you drive the camera
rem                       (WASD/edge-pan = pan, Q/E = orbit, R/F = tilt,
rem                        mouse wheel = zoom; close the window to quit)
rem   game.bat measure    measurement mode - the M1 fps run: auto-orbits,
rem                       prints an fps sample block, quits by itself
rem   game.bat tests      headless test suite (tools\run_tests.sh via Git Bash)
rem ============================================================================
setlocal
set "GODOT=%~dp0godot\Godot_v4.7-stable_win64_console.exe"

if not exist "%GODOT%" (
  echo game.bat: repo-local Godot missing at godot\ - see README "Self-contained toolchain".
  exit /b 2
)

if /i "%~1"=="measure" (
  "%GODOT%" --path "%~dp0." --resolution 1600x900 scenes/Main.tscn
) else if /i "%~1"=="tests" (
  where bash >nul 2>nul
  if errorlevel 1 (
    echo game.bat: 'bash' not found on PATH - run: bash tools/run_tests.sh from Git Bash.
    exit /b 2
  )
  bash "%~dp0tools/run_tests.sh"
) else (
  "%GODOT%" --path "%~dp0." --resolution 1600x900 scenes/Play.tscn
)

endlocal
