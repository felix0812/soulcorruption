@echo off
rem Startet SoulCorruption mit dem OpenGL-Renderer.
rem Hilft bei Abstuerzen oder Grafikfehlern durch Grafiktreiber.
cd /d "%~dp0"
start "" "SoulCorruption.exe" --rendering-method gl_compatibility --rendering-driver opengl3
