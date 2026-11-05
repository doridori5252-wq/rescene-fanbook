@echo off
chcp 65001 >nul
title R: 팬노트 - 구글 플레이 출시용 파일(.aab) 만들기
echo ============================================
echo   R: 팬노트 - 구글 플레이 출시용 .aab
echo ============================================
echo.
set "JAVA_HOME=D:\android-build\jdk-tmp\jdk-17.0.19+10"
set "ANDROID_SDK_ROOT=D:\android-build\sdk"
set "ANDROID_HOME=D:\android-build\sdk"
set "PATH=%JAVA_HOME%\bin;D:\android-build\gradle\gradle-8.13\bin;D:\android-build\sdk\platform-tools;%PATH%"
set "GRADLE_USER_HOME=D:\android-build\gradle-home"
if not exist "D:\android-build\tmp\gradle" mkdir "D:\android-build\tmp\gradle"
set "TEMP=D:\android-build\tmp\gradle"
set "TMP=D:\android-build\tmp\gradle"
set "PROPS=D:\android-build\keys\rescene-key.properties"

if not exist "%PROPS%" (
  echo [오류] 서명 키 정보 파일이 없습니다: %PROPS%
  echo        D:\android-build\keys 의 rescene-upload.jks 와 rescene-key.properties 가 있어야 합니다.
  pause & exit /b 1
)
for /f "usebackq tokens=1,* delims==" %%a in ("%PROPS%") do set "%%a=%%b"

cd /d "%~dp0"
if not exist node_modules call npm install
if not exist "platforms\android" call npx cordova platform add android --nosave
call npx cordova prepare android
if errorlevel 1 ( echo [실패] prepare 중 오류. & pause & exit /b 1 )

echo 출시용 .aab 빌드를 시작합니다. 몇 분 걸릴 수 있습니다.
cd /d "%~dp0platforms\android"
call gradle bundleRelease assembleRelease --console=plain -Pandroid.injected.signing.store.file="%storeFile%" -Pandroid.injected.signing.store.password="%storePassword%" -Pandroid.injected.signing.key.alias=%keyAlias% -Pandroid.injected.signing.key.password="%keyPassword%"
set "RESULT=%errorlevel%"
set "storePassword=" & set "keyPassword="
if not "%RESULT%"=="0" ( echo. & echo [실패] 빌드 중 오류가 발생했습니다. 화면을 캡처해 알려주세요. & pause & exit /b 1 )

set "AAB=app\build\outputs\bundle\release\app-release.aab"
set "RAPK=app\build\outputs\apk\release\app-release.apk"
if exist "%AAB%" (
  if not exist "D:\앱" mkdir "D:\앱"
  copy /Y "%AAB%" "D:\앱\R팬노트_출시용.aab" >nul
  if exist "%RAPK%" copy /Y "%RAPK%" "D:\앱\R팬노트_출시용.apk" >nul
  echo.
  echo [성공] D:\앱 폴더에 R팬노트_출시용.aab 가 만들어졌습니다!
  echo  다음 출시 때는 config.xml 의 version 을 올린 뒤 이 파일을 다시 실행하세요.
) else ( echo [오류] .aab 파일을 찾지 못했습니다: %AAB% )
echo.
pause
