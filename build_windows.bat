@echo off
echo ===================================================
echo   LanSync Windows 桌面版一键打包脚本
echo ===================================================

echo 正在检查 Flutter 环境...
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [错误] 未在 PATH 中找到 flutter 命令，请先安装 Flutter SDK 并配置环境变量。
    pause
    exit /b 1
)

echo 正在拉取依赖...
call flutter pub get

echo 正在编译 Windows Release 版本...
call flutter build windows --release
if %errorlevel% neq 0 (
    echo [错误] 编译失败，请确保安装了 Visual Studio "使用 C++ 的桌面开发" 组件。
    pause
    exit /b 1
)

set OUT_DIR=build\windows\x64\runner\Release
set ZIP_NAME=LanSync-Windows-x64.zip

echo 正在创建压缩包 %ZIP_NAME%...
powershell -Command "Compress-Archive -Path '%OUT_DIR%\*' -DestinationPath '%ZIP_NAME%' -Force"

echo ===================================================
echo [成功] Windows 版打包完成！
echo 产物位置: %cd%\%ZIP_NAME%
echo ===================================================
pause
