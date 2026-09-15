#!/bin/bash
set -e

echo "=== LanSync Linux 桌面版一键打包脚本 ==="

# 检查编译依赖
MISSING_PKGS=""
for pkg in clang libgtk-3-dev pkg-config ninja-build; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "检测到缺少编译依赖: $MISSING_PKGS"
    echo "正在尝试自动安装依赖 (可能需要输入 sudo 密码)..."
    sudo apt-get update && sudo apt-get install -y $MISSING_PKGS
fi

echo "正在执行 Release 编译..."
export FLUTTER_ROOT=/home/ygsj/software/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn

flutter build linux --release

OUT_DIR="build/linux/x64/release/bundle"
ARCHIVE_NAME="LanSync-Linux-x64.tar.gz"

if [ -d "$OUT_DIR" ]; then
    echo "正在打包归档: $ARCHIVE_NAME ..."
    tar -czf "$ARCHIVE_NAME" -C "$OUT_DIR" .
    echo "=== 打包完成！==="
    echo "输出二进制目录: $OUT_DIR"
    echo "便携压缩包: $(pwd)/$ARCHIVE_NAME"
fi
