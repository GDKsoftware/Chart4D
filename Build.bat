@echo off
setlocal enabledelayedexpansion

rem Where RAD Studio is installed. Only needed to locate rsvars.bat, which then exports
rem BDS, BDSCOMMONDIR and BDSUSERDIR for everything this script calls.
if not defined STUDIO_ROOT set "STUDIO_ROOT=C:\Program Files (x86)\Embarcadero\Studio"

rem Newest supported Delphi first: 37.0 is Delphi 13, 23.0 is Delphi 12 Athens.
rem Set CHART4D_STUDIO to a version number to force one of them, or BDS to point at
rem an installation directly:  set BDS=D:\Embarcadero\Studio\23.0
if not defined BDS (
  if defined CHART4D_STUDIO (
    set "BDS=%STUDIO_ROOT%\%CHART4D_STUDIO%"
  ) else (
    for %%V in (37.0 23.0) do (
      if not defined BDS if exist "%STUDIO_ROOT%\%%V\bin\rsvars.bat" set "BDS=%STUDIO_ROOT%\%%V"
    )
  )
)
if not defined BDS (
  echo No supported Delphi found under "%STUDIO_ROOT%".
  echo Looked for 37.0 ^(Delphi 13^) and 23.0 ^(Delphi 12 Athens^).
  echo Set CHART4D_STUDIO to a version number, or STUDIO_ROOT to another install root.
  exit /b 1
)

rem The package sources live in a folder per product version.
set "PACKAGEDIR=packages\RAD Studio 13.0"
if "%BDS:~-4%"=="23.0" set "PACKAGEDIR=packages\RAD Studio 12.0"

set RSVARS="%BDS%\bin\rsvars.bat"
set CONFIG=Release

echo ===============================================
echo Chart4D build (%BDS%)
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
echo --- Building design-time packages (%CONFIG%, %PLATFORM%) ---

call :BuildPackage Chart4D_VCL_D.dproj
if errorlevel 1 exit /b 1

call :BuildPackage Chart4D_FMX_D.dproj
if errorlevel 1 exit /b 1

rem The IDE can run as a 64-bit process, and a 64-bit IDE loads Win64x design-time
rem packages, which need their runtime packages on Win64x as well. Delphi 12 has no
rem Win64x platform, so this round is skipped there.
if not "%BDS:~-4%"=="23.0" (
  set PLATFORM=Win64x

  echo.
  echo --- Building packages for the 64-bit IDE ^(%CONFIG%, Win64x^) ---

  for %%K in (Chart4D_R.dproj Chart4D_VCL_R.dproj Chart4D_FMX_R.dproj Chart4D_VCL_D.dproj Chart4D_FMX_D.dproj) do (
    call :BuildPackage %%K
    if errorlevel 1 exit /b 1
  )

  set PLATFORM=Win32
)

echo.
echo --- Building and running tests ---

rem Both platforms, because Win64 maps Extended onto Double: the same source can be
rem correct on one and wrong on the other.
if exist "Tests\build.bat" (
  for %%P in (Win32 Win64) do (
    call :BuildAndRunTests %%P
    if errorlevel 1 exit /b 1
  )
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

:BuildAndRunTests
set TESTPLATFORM=%~1
echo.
echo --- %TESTPLATFORM% ---
pushd Tests
call .\build.bat %TESTPLATFORM%
if errorlevel 1 (
  popd
  echo Tests build failed for %TESTPLATFORM%!
  exit /b 1
)
if exist "%TESTPLATFORM%\Debug\Chart4D.Tests.exe" (
  %TESTPLATFORM%\Debug\Chart4D.Tests.exe
  if errorlevel 1 (
    popd
    echo Tests failed for %TESTPLATFORM%!
    exit /b 1
  )
) else (
  echo Test executable for %TESTPLATFORM% not found, skipping test run.
)
popd
exit /b 0
