@echo off

rem zum richtigen Laufwerk wechseln (aus %0 ermittelt)
%~d0

rem in das Projekt-Verzeichnis wechseln (aus %0 ermittelt)
cd %~p0

rem Den Namen des Projekts ermitteln
for /f "delims=\\" %%I in ('cd') do set PROJECT=%%~nxI

rem In das Tools-Verzeichnis wechseln (aus %0)
cd %~p0\..\..\Tools

rem Das Batch-File zum Schreiben der VHDL-Dateien aufrufen
call write_vhdl.bat %PROJECT%
