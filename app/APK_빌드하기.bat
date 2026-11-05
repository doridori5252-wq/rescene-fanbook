@echo off
chcp 65001 >nul
title 리센느팬북 - APK 빌드
echo ============================================
echo   리센느 팬북 - APK 빌드
echo ============================================
echo.

REM ---- 로또앱과 동일한 빌드 환경을 그대로 씁니다 ----
set "JAVA_HOME=D:\android-build\jdk-tmp\jdk-17.0.19+10"
set "ANDROID_SDK_ROOT=D:\android-build\sdk"
set "ANDROID_HOME=D:\android-build\sdk"
set "GRADLE_USER_HOME=D:\android-build\gradle-home"
set "PATH=%JAVA_HOME%\bin;D:\android-build\gradle\gradle-8.13\bin;%ANDROID_HOME%\platform-tools;%PATH%"

cd /d "%~dp0"
if not exist node_modules call npm install

if not exist "%JAVA_HOME%\bin\java.exe" (
  echo [오류] JDK 를 찾지 못했습니다: %JAVA_HOME%
  echo        D:\android-build 안의 JDK 폴더 이름이 바뀌었는지 확인해 주세요.
  pause & exit /b 1
)

echo [1/3] 안드로이드 플랫폼 준비...
if not exist "platforms\android" (
  call npx cordova platform add android@13
  if errorlevel 1 ( echo [실패] 플랫폼 추가 중 오류. & pause & exit /b 1 )
) else (
  echo       이미 추가되어 있습니다.
)

echo.
echo [2/3] 플러그인 반영...
call npx cordova prepare android
if errorlevel 1 ( echo [실패] prepare 중 오류. & pause & exit /b 1 )

echo.
echo [3/3] APK 빌드... (처음에는 구성요소를 받느라 몇 분 걸립니다)
echo.
call npx cordova build android --console=plain
if errorlevel 1 ( echo. & echo [실패] 빌드 중 오류가 발생했습니다. 화면 내용을 캡처해 알려주세요. & pause & exit /b 1 )

set "APK=platforms\android\app\build\outputs\apk\debug\app-debug.apk"
if exist "%APK%" (
  copy /Y "%APK%" "%USERPROFILE%\Desktop\리센느팬북.apk" >nul
  echo.
  echo ============================================
  echo [성공] 바탕화면에 리센느팬북.apk 가 만들어졌습니다!
  echo ============================================
  echo.
  echo  휴대폰에 USB 로 연결한 뒤 아래 명령으로 바로 설치할 수도 있습니다:
  echo    npx cordova run android
) else (
  echo [오류] APK 파일을 찾지 못했습니다: %APK%
)
echo.
pause
