#!/bin/bash
set -e

APP_NAME="lansync"
VERSION="1.0.0"
ARCH="amd64"
DEB_DIR="build/deb_dist/${APP_NAME}_${VERSION}_${ARCH}"

echo "=== 正在准备构建 ${APP_NAME} 的 .deb 安装包 ==="

# 检查构建依赖
if ! command -v clang++ >/dev/null 2>&1 || ! pkg-config --exists gtk+-3.0; then
    echo "【提示】缺少 Linux 桌面编译依赖 (clang 或 libgtk-3-dev)。"
    echo "请先在终端运行: sudo apt update && sudo apt install -y clang libgtk-3-dev pkg-config"
    exit 1
fi

echo "1. 正在编译 Linux Release 二进制..."
export FLUTTER_ROOT=/home/ygsj/software/flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter build linux --release

echo "2. 正在构建 Debian 标准安装包文件结构..."
rm -rf "build/deb_dist"
mkdir -p "${DEB_DIR}/DEBIAN"
mkdir -p "${DEB_DIR}/opt/${APP_NAME}"
mkdir -p "${DEB_DIR}/usr/bin"
mkdir -p "${DEB_DIR}/usr/share/applications"
mkdir -p "${DEB_DIR}/usr/share/icons/hicolor/512x512/apps"

# 拷贝二进制和资源
cp -r build/linux/x64/release/bundle/* "${DEB_DIR}/opt/${APP_NAME}/"
cp assets/logo.png "${DEB_DIR}/usr/share/icons/hicolor/512x512/apps/${APP_NAME}.png"

# 创建软链接到 /usr/bin/lansync
cat <<EOF > "${DEB_DIR}/usr/bin/${APP_NAME}"
#!/bin/bash
exec /opt/${APP_NAME}/file_sync "\$@"
EOF
chmod +x "${DEB_DIR}/usr/bin/${APP_NAME}"

# 创建桌面快捷方式 (.desktop)
cat <<EOF > "${DEB_DIR}/usr/share/applications/${APP_NAME}.desktop"
[Desktop Entry]
Name=LanSync
Comment=Secure Local Network P2P File Transfer
Exec=/usr/bin/${APP_NAME}
Icon=${APP_NAME}
Terminal=false
Type=Application
Categories=Network;FileTransfer;Utility;
Keywords=sync;transfer;p2p;lan;
EOF

# 创建 Debian 控制描述文件
cat <<EOF > "${DEB_DIR}/DEBIAN/control"
Package: ${APP_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCH}
Maintainer: LanSync Developer <support@lansync.org>
Depends: libgtk-3-0 (>= 3.24.0)
Description: LanSync - Secure Local Network Peer-to-Peer File Transfer Tool
 A cross-platform peer-to-peer file transfer tool for local area networks
 featuring cryptographic device trust authorization and high-speed streaming.
EOF

echo "3. 正在封装生成 .deb 包..."
dpkg-deb --build "${DEB_DIR}" "${APP_NAME}_${VERSION}_${ARCH}.deb"

echo "=== .deb 打包完成！==="
echo "安装包位置: $(pwd)/${APP_NAME}_${VERSION}_${ARCH}.deb"
echo "安装命令: sudo dpkg -i ${APP_NAME}_${VERSION}_${ARCH}.deb"
