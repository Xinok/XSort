rem Batch 12.06.04

echo off
cls

call clean.bat
cls

dmd @build.args

if NOT EXIST *.exe (
pause
exit
)
start benchsort.exe
pause
exit