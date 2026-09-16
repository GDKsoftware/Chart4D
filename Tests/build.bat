@echo off
setlocal

rem Platform to build for: Win32 (the default) or Win64. Build.bat passes both in turn.
rem The two differ in more than the compiler: Win64 maps Extended onto Double, so a
rem precision bug can be present on one platform and absent on the other.
set "TARGET_PLATFORM=%~1"
if not defined TARGET_PLATFORM set "TARGET_PLATFORM=Win32"

if /I "%TARGET_PLATFORM%"=="Win32" set "COMPILER=dcc32.exe"
if /I "%TARGET_PLATFORM%"=="Win64" set "COMPILER=dcc64.exe"
if not defined COMPILER (
  echo Unknown platform "%TARGET_PLATFORM%". Use Win32 or Win64.
  exit /b 1
)

rem RAD Studio locations. rsvars.bat and the IDE both export BDS, BDSCOMMONDIR and
rem BDSUSERDIR; the defaults below apply only when this script runs in a plain shell.
rem Point BDS at another installation to build against a different RAD Studio.
if not defined BDS set "BDS=c:\program files (x86)\embarcadero\studio\37.0"
if not defined BDSCOMMONDIR set "BDSCOMMONDIR=C:\Users\Public\Documents\Embarcadero\Studio\37.0"
if not defined BDSUSERDIR set "BDSUSERDIR=%USERPROFILE%\Documents\Embarcadero\Studio\37.0"

set DCC="%BDS%\bin\%COMPILER%"
set PROJECT=Chart4D.Tests.dpr
set OUTPUT_DIR=.\%TARGET_PLATFORM%\Debug

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

echo Building %PROJECT% for %TARGET_PLATFORM%...

%DCC% -$O- -$W+ --no-config -B -Q -TX.exe ^
  -AGenerics.Collections=System.Generics.Collections;Generics.Defaults=System.Generics.Defaults;WinTypes=Winapi.Windows;WinProcs=Winapi.Windows;DbiTypes=BDE;DbiProcs=BDE;DbiErrs=BDE ^
  -DDEBUG;CI ^
  -E%OUTPUT_DIR% ^
  -I"%BDS%\lib\%TARGET_PLATFORM%\debug";..\Source;..\Examples\Common;"%BDS%\source\DunitX";"%BDS%\lib\%TARGET_PLATFORM%\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\%TARGET_PLATFORM%";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -LE"%BDSCOMMONDIR%\Bpl" ^
  -LN"%BDSCOMMONDIR%\Dcp" ^
  -NU%OUTPUT_DIR% ^
  -NSSystem.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;Bde;System;Xml;Data;Datasnap;Web;Soap;Winapi; ^
  -O..\Source;..\Examples\Common;"%BDS%\lib\%TARGET_PLATFORM%\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\%TARGET_PLATFORM%";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -R..\Source;..\Examples\Common;"%BDS%\lib\%TARGET_PLATFORM%\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\%TARGET_PLATFORM%";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -U"%BDS%\lib\%TARGET_PLATFORM%\debug";..\Source;..\Examples\Common;"%BDS%\source\DunitX";"%BDS%\lib\%TARGET_PLATFORM%\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\%TARGET_PLATFORM%";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -V ^
  -VN ^
  -NB"%BDSCOMMONDIR%\Dcp" ^
  -NH"%BDSCOMMONDIR%\hpp\%TARGET_PLATFORM%" ^
  -NO%OUTPUT_DIR% ^
  %PROJECT%

if errorlevel 1 (
  echo Build failed!
  exit /b 1
)

echo Build successful!
echo Executable: %OUTPUT_DIR%\Chart4D.Tests.exe
