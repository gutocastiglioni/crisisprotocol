@echo off
rem Abre o jogo (clique duplo). Argumentos extras vão para o jogo, ex.: jogar.bat -- --gfx=ps2
where godot >nul 2>nul
if errorlevel 1 (
    echo Godot nao encontrado no PATH. Instale o Godot 4 ^(winget install GodotEngine.GodotEngine^) e tente de novo.
    pause
    exit /b 1
)
start "" godot --path "%~dp0game" %*
