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
haxelib run lime test windows -debug
echo.
echo done.
pause