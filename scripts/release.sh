#!/bin/bash
# 构建并打包 zip + dmg：scripts/release.sh  →  dist/QingRight-<版本>.{zip,dmg}
set -euo pipefail
cd "$(dirname "$0")/.."
VER=$(grep -m1 'MARKETING_VERSION: "' project.yml | cut -d'"' -f2)
# 构建目录放内置盘：exFAT 等盘会生成 ._ 文件破坏签名
B=${QINGRIGHT_BUILD:-$HOME/Library/Developer/QingRightBuild}
OUT=${QINGRIGHT_DIST:-$HOME/Library/Developer/QingRightDist}
xcodegen generate -q
rm -rf "$B"
xcodebuild -project QingRight.xcodeproj -scheme QingRight -configuration Release -derivedDataPath "$B" build -quiet
APP="$B/Build/Products/Release/QingRight.app"
codesign --verify --deep --strict "$APP"
mkdir -p "$OUT"; rm -f "$OUT/QingRight-$VER".{zip,dmg}
ditto -c -k --norsrc --keepParent "$APP" "$OUT/QingRight-$VER.zip"
S=$(mktemp -d); ditto --norsrc "$APP" "$S/QingRight.app"; ln -s /Applications "$S/应用程序"
hdiutil create -quiet -volname "轻右键 $VER" -srcfolder "$S" -fs HFS+ -format ULMO "$OUT/QingRight-$VER.dmg"
rm -rf "$S"
ls -l "$OUT/QingRight-$VER".*
shasum -a 256 "$OUT/QingRight-$VER".*
