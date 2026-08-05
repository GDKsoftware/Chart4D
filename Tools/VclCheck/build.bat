@echo off
setlocal

rem RAD Studio locations. rsvars.bat and the IDE both export BDS, BDSCOMMONDIR and
rem BDSUSERDIR; the defaults below apply only when this script runs in a plain shell.
rem Point BDS at another installation to build against a different RAD Studio.
if not defined BDS set "BDS=c:\program files (x86)\embarcadero\studio\37.0"
if not defined BDSCOMMONDIR set "BDSCOMMONDIR=C:\Users\Public\Documents\Embarcadero\Studio\37.0"
if not defined BDSUSERDIR set "BDSUSERDIR=%USERPROFILE%\Documents\Embarcadero\Studio\37.0"

set DCC32="%BDS%\bin\dcc32.exe"
set PROJECT=VclCheck.dpr
set OUTPUT_DIR=.\Win32\Debug

if not exist %OUTPUT_DIR% mkdir %OUTPUT_DIR%

echo Building %PROJECT%...

%DCC32% -$O- -$W+ --no-config -B -Q -TX.exe ^
  -AGenerics.Collections=System.Generics.Collections;Generics.Defaults=System.Generics.Defaults;WinTypes=Winapi.Windows;WinProcs=Winapi.Windows;DbiTypes=BDE;DbiProcs=BDE;DbiErrs=BDE ^
  -DDEBUG ^
  -E%OUTPUT_DIR% ^
  -I"%BDS%\lib\Win32\debug";..\..\Source;..\..\Source\VCL;"%BDS%\lib\Win32\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\Win32";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -LE"%BDSCOMMONDIR%\Bpl" ^
  -LN"%BDSCOMMONDIR%\Dcp" ^
  -NU%OUTPUT_DIR% ^
  -NSSystem.Win;Data.Win;Datasnap.Win;Web.Win;Soap.Win;Xml.Win;Bde;System;Xml;Data;Datasnap;Web;Soap;Winapi; ^
  -O..\..\Source;..\..\Source\VCL;"%BDS%\lib\Win32\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\Win32";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -R..\..\Source;..\..\Source\VCL;"%BDS%\lib\Win32\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\Win32";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -U"%BDS%\lib\Win32\debug";..\..\Source;..\..\Source\VCL;"%BDS%\lib\Win32\release";"%BDSUSERDIR%\Imports";"%BDSUSERDIR%\Imports\Win32";"%BDS%\Imports";"%BDSCOMMONDIR%\Dcp";"%BDS%\include" ^
  -V ^
  -VN ^
  -NB"%BDSCOMMONDIR%\Dcp" ^
  -NH"%BDSCOMMONDIR%\hpp\Win32" ^
  -NO%OUTPUT_DIR% ^
  %PROJECT%

if errorlevel 1 (
  echo Build failed!
  exit /b 1
)

echo Build successful!
echo Executable: %OUTPUT_DIR%\VclCheck.exe
