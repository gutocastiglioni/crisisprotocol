@echo off
rem Exporta os bundles e compila o instalador diretamente na pasta INSTALADOR
where godot >nul 2>nul
if errorlevel 1 (
    echo Godot nao encontrado no PATH.
    pause
    exit /b 1
)

echo [1/4] Exportando Crisis Protocol para Windows (Portatil)...
if not exist "%~dp0INSTALADOR\Versao_Portatil_Windows" mkdir "%~dp0INSTALADOR\Versao_Portatil_Windows"
if not exist "%~dp0INSTALADOR\Versao_Modular_Windows" mkdir "%~dp0INSTALADOR\Versao_Modular_Windows"
if not exist "%~dp0INSTALADOR\Versao_Linux" mkdir "%~dp0INSTALADOR\Versao_Linux"

godot --headless --path "%~dp0game" --export-release "Windows Desktop" "%~dp0INSTALADOR\Versao_Portatil_Windows\CrisisProtocol.exe"

echo [2/4] Exportando versao modular (.pck separado)...
godot --headless --path "%~dp0game" --export-release "Windows Desktop (Separated PCK)" "%~dp0INSTALADOR\Versao_Modular_Windows\CrisisProtocol.exe"

echo [3/4] Exportando versao nativa para Linux (x86_64 / SteamOS)...
godot --headless --path "%~dp0game" --export-release "Linux Desktop" "%~dp0INSTALADOR\Versao_Linux\CrisisProtocol.x86_64"

set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=C:\Program Files\Inno Setup 6\ISCC.exe"

if exist "%ISCC%" (
    echo [4/4] Gerando Instalador CrisisProtocol_Setup.exe...
    "%ISCC%" "%~dp0tools\installer.iss"
) else (
    echo [Aviso] Inno Setup nao localizado para gerar o instalador Setup.exe.
)

echo.
echo ======================================================================
echo  Concluido com sucesso! Todos os arquivos estao na pasta: INSTALADOR\
echo ======================================================================
pause
