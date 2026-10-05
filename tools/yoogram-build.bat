@echo off
setlocal EnableDelayedExpansion
rem YooGram: build everything on Windows with one script.
rem Put the cloned repository into a SHORT path without spaces, e.g.
rem D:\TBuild\YooGram-Desktop, and run this file from there (double click works).
rem Needs: Visual Studio with C++ tools (MSVC v14.44, Windows SDK), Python, Git.

set "REPO=%~dp0.."
for %%I in ("%REPO%") do set "REPO=%%~fI"

echo === Looking for Visual Studio ===
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo vswhere.exe not found. Install Visual Studio with the C++ workload.
  goto fail
)
rem Prefer Visual Studio 2022 (17.x): several libraries are built with MSBuild
rem and the v143 toolset, which Visual Studio 2026 does not provide.
set "VSPATH="
for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -version "[17.0,18.0)" -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
if not defined VSPATH (
  echo Visual Studio 2022 was not found, trying the newest Visual Studio.
  echo NOTE: Visual Studio 2026 has no v143 MSBuild toolset, building libraries may fail.
  echo Install Visual Studio 2022 17.14 with the C++ workload.
  for /f "usebackq delims=" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSPATH=%%i"
)
if not defined VSPATH (
  echo Visual Studio with the C++ x64 tools was not found.
  goto fail
)
echo Found: %VSPATH%

echo === Setting up the x64 environment ===
call "%VSPATH%\VC\Auxiliary\Build\vcvars64.bat" -vcvars_ver=14.44
if errorlevel 1 (
  echo vcvars64.bat failed. In the Visual Studio Installer add the component
  echo "MSVC v14.44 build tools" and the Windows SDK 10.0.26100.0.
  goto fail
)

rem Force English compiler messages. ffmpeg's configure recognizes MSVC by the
rem English banner of cl.exe; with a localized Visual Studio (e.g. Russian) it
rem fails with "LNK1136" / "C compiler test failed".
set VSLANG=1033
set LANG=en_US.UTF-8

where python >nul 2>nul
if errorlevel 1 (
  echo Python was not found in PATH. Install Python 3.10 and tick "Add to PATH".
  goto fail
)
where git >nul 2>nul
if errorlevel 1 (
  echo Git was not found in PATH.
  goto fail
)

if not defined TDESKTOP_API_ID set /p TDESKTOP_API_ID=Your api_id from my.telegram.org: 
if not defined TDESKTOP_API_HASH set /p TDESKTOP_API_HASH=Your api_hash: 

rem More robust Git networking for this run only (no global config changes):
rem the OpenSSL backend instead of schannel and HTTP/1.1 fix most
rem "connection reset" / "missing close_notify" errors when cloning.
set GIT_CONFIG_COUNT=3
set GIT_CONFIG_KEY_0=http.sslBackend
set GIT_CONFIG_VALUE_0=openssl
set GIT_CONFIG_KEY_1=http.version
set GIT_CONFIG_VALUE_1=HTTP/1.1
set GIT_CONFIG_KEY_2=http.postBuffer
set GIT_CONFIG_VALUE_2=524288000

echo === Building libraries (1-3 hours the first time, safe to re-run) ===
set /a TRIES=0
:prepare
set /a TRIES+=1
call "%REPO%\Telegram\build\prepare\win.bat" silent qt6
if not errorlevel 1 goto prepared
if %TRIES% geq 6 goto fail
echo.
echo Libraries failed (attempt %TRIES% of 6). Finished stages are skipped, retrying
echo in 15 seconds. Network errors are common, a real build error will repeat.
timeout /t 15 /nobreak >nul
goto prepare
:prepared

rem The app links FFmpeg as lib<name>.a (cmake_helpers), but an MSVC build of
rem FFmpeg may leave lib<name>.lib. A copy under the expected name is harmless.
set "FFDIR=%REPO%\..\Libraries\win64\ffmpeg"
for %%L in (avfilter avformat avcodec swresample swscale avutil) do (
  if not exist "!FFDIR!\lib%%L\lib%%L.a" (
    if exist "!FFDIR!\lib%%L\lib%%L.lib" (
      echo FFmpeg: copying lib%%L.lib to lib%%L.a
      copy /y "!FFDIR!\lib%%L\lib%%L.lib" "!FFDIR!\lib%%L\lib%%L.a" >nul
    )
  )
)

echo === Configuring ===
cd /d "%REPO%\Telegram"
call configure.bat x64 qt6 -D TDESKTOP_API_ID=%TDESKTOP_API_ID% -D TDESKTOP_API_HASH=%TDESKTOP_API_HASH% -D DESKTOP_APP_DISABLE_AUTOUPDATE=ON -D CMAKE_CONFIGURATION_TYPES=Release
if errorlevel 1 goto fail

echo === Building YooGram (Release) ===
cmake --build ..\out --config Release --parallel
if errorlevel 1 goto fail

echo.
echo DONE. Telegram.exe is in %REPO%\out\Release
pause
exit /b 0

:fail
echo.
echo FAILED. Copy the last 30-40 lines above (before this message) and send them.
pause
exit /b 1
