@echo off
REM Engega el disparador. Deixa aquesta finestra oberta (es pot minimitzar).
cd /d "%~dp0"
node --env-file=disparador.env disparador.js
pause
