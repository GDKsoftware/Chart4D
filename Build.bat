@echo off
setlocal enabledelayedexpansion

rem Where RAD Studio is installed. Only needed to locate rsvars.bat, which then exports
rem BDS, BDSCOMMONDIR and BDSUSERDIR for everything this script calls. Set BDS yourself
rem to build against another installation:  set BDS=D:\Embarcadero\Studio\37.0
if not defined BDS set "BDS=c:\program files (x86)\embarcadero\studio\37.0"

set RSVARS="%BDS%\bin\rsvars.bat"
set PACKAGEDIR=packages\RAD Studio 13.0
set CONFIG=Release

echo ===============================================
echo Chart4D build
echo ===============================================

if not exist %RSVARS% (
  echo rsvars.bat not found at %RSVARS%
  exit /b 1
)

call %RSVARS%
if errorlevel 1 (
  echo Failed to initialize RAD Studio environment.
  exit /b 1
)

rem rsvars.bat clears the PLATFORM environment variable, so it must be
rem (re)set after calling it, not before.
set PLATFORM=Win32

echo.
echo --- Building runtime packages (%CONFIG%, %PLATFORM%) ---

call :BuildPackage Chart4D_R.dproj
if errorlevel 1 exit /b 1

call :BuildPackage Chart4D_VCL_R.dproj
if errorlevel 1 exit /b 1

call :BuildPackage Chart4D_FMX_R.dproj
if errorlevel 1 exit /b 1

echo.
echo --- Building and running tests ---

if exist "Tests\build.bat" (
  pushd Tests
  call .\build.bat
  if errorlevel 1 (
    popd
    echo Tests build failed!
    exit /b 1
  )
  if exist "Win32\Debug\Chart4D.Tests.exe" (
    Win32\Debug\Chart4D.Tests.exe
    if errorlevel 1 (
      popd
      echo Tests failed!
      exit /b 1
    )
  ) else (
    echo Test executable not found, skipping test run.
  )
  popd
) else (
  echo Tests\build.bat not found yet, skipping tests.
)

echo.
echo --- Building demos ---

if exist "Examples\VCL\build.bat" (
  pushd Examples\VCL
  call .\build.bat
  if errorlevel 1 (
    popd
    echo VCL demo build failed!
    exit /b 1
  )
  popd
) else (
  echo Examples\VCL\build.bat not found yet, skipping VCL demo.
)

if exist "Examples\FMX\build.bat" (
  pushd Examples\FMX
  call .\build.bat
  if errorlevel 1 (
    popd
    echo FMX demo build failed!
    exit /b 1
  )
  popd
) else (
  echo Examples\FMX\build.bat not found yet, skipping FMX demo.
)

echo.
echo ===============================================
echo Chart4D build finished successfully
echo ===============================================
exit /b 0

:BuildPackage
set PACKAGENAME=%~1
echo.
echo Building %PACKAGENAME%...
msbuild "%PACKAGEDIR%\%PACKAGENAME%" /t:Build /p:Config=%CONFIG% /p:Platform=%PLATFORM%
if errorlevel 1 (
  echo Build of %PACKAGENAME% failed!
  exit /b 1
)
exit /b 0
