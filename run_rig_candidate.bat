@echo off
setlocal
for %%I in ("%~dp0.") do set "PROJECT_DIR=%%~fI"
set "GODOT_EXE=C:\Program Files\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%PROJECT_DIR%\project.godot" (
    echo ERROR: project.godot not found in %PROJECT_DIR%
    pause
    exit /b 1
)
if not exist "%GODOT_EXE%" (
    echo ERROR: Godot executable not found: %GODOT_EXE%
    pause
    exit /b 1
)
echo Starting TASK-009 isolated rig candidate v009...
"%GODOT_EXE%" --path "%PROJECT_DIR%" %* res://debug/fps_rig_test.tscn -- --candidate --clean
set "GODOT_EXIT_CODE=%ERRORLEVEL%"
echo Godot exited with code %GODOT_EXIT_CODE%.
pause
exit /b %GODOT_EXIT_CODE%
