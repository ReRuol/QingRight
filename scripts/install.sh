#!/bin/bash
# 轻右键一键安装：curl -fsSL https://raw.githubusercontent.com/ReRuol/QingRight/master/scripts/install.sh | bash
# curl 下载不带隔离标记，所以不会被 Gatekeeper 拦；装到 /Applications 后自动启用访达扩展
set -euo pipefail
REPO=ReRuol/QingRight
VER=${QINGRIGHT_VERSION:-$(curl -fsSL "https://api.github.com/repos/$REPO/releases" | grep -m1 '"tag_name"' | cut -d'"' -f4)}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
echo "下载轻右键 $VER ..."
curl -fsSL "https://github.com/$REPO/releases/download/$VER/QingRight-${VER#v}.zip" -o "$TMP/q.zip"
ditto -x -k "$TMP/q.zip" "$TMP"
pkill -x QingRight 2>/dev/null || true
rm -rf /Applications/QingRight.app
mv "$TMP/QingRight.app" /Applications/
xattr -dr com.apple.quarantine /Applications/QingRight.app 2>/dev/null || true
pluginkit -a /Applications/QingRight.app/Contents/PlugIns/QingRightFinder.appex
pluginkit -e use -i com.reruol.qingright.finder
open /Applications/QingRight.app
echo "✅ 已安装 $VER，现在在访达里点右键试试。"
