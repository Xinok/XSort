rem DGUI Batch 12.06.04

echo off
cls

if EXIST build\benchsort.exe (
del build\benchsort.exe
)

dmd @build.args

if NOT EXIST build\benchsort.exe (
echo Build Failed
pause
exit
)
build\benchsort.exe
pause
exit