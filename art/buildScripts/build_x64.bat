@echo off
color 0a
cd ../..
if not exist ".haxelib\" (
	echo Falta la carpeta de librerias de Flux: primero abre setup\windows.bat
	echo.
	pause
	exit /b 1
)
echo BUILDING GAME
haxelib run lime build windows -release
echo.
echo done.
pause
pwd
explorer.exe export\release\windows\bin