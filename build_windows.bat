@echo off
setlocal
cd /d %~dp0
echo === PureBili Windows build ===
where flutter >nul 2>nul || (echo [ERROR] Flutter SDK not found in PATH. Install Flutter 3.27+ first. & pause & exit /b 1)
if not exist windows (
  echo Generating platform folders...
  call flutter create --platforms=windows,android,ios,macos --org com.purebili --project-name purebili . || goto :fail
)
call dart run tool/patch_platforms.dart || goto :fail
call flutter pub get || goto :fail
call dart run flutter_launcher_icons || goto :fail
call flutter build windows --release || goto :fail
powershell -NoProfile -Command "Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'PureBili-windows-x64.zip' -Force" || goto :fail
echo.
echo Done: build\windows\x64\runner\Release\purebili.exe
echo Zip : PureBili-windows-x64.zip
pause
exit /b 0
:fail
echo [ERROR] Build failed. See messages above.
pause
exit /b 1
