#!/usr/bin/env bash
# AI Review インストーラ（社内配布用 / 自動パス検出版）
#
# 受け取った人がダブルクリックするだけで AI Review.app を組み立てます。
# 開発者用に焼き付いていた node / CLI のパスを、この人のMac用に自動解決します。
#
# 検証用に環境変数で出力先を上書きできます:
#   APP_NAME="AI Review TEST" APP_DIR=/tmp/airev-test BUNDLE_ID=com.example.aireview.test ./install.command
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../ai-review-comments/macos
REPO="$(cd "$HERE/.." && pwd)"                          # .../ai-review-comments
CLI_PATH="$REPO/cli/ai-review.mjs"
TEMPLATE="$HERE/AI-Review.applescript.in"

APP_NAME="${APP_NAME:-AI Review}"
APP_DIR="${APP_DIR:-/Applications}"
APP="$APP_DIR/$APP_NAME.app"
BUNDLE_ID="${BUNDLE_ID:-com.example.aireview}"

PB=/usr/libexec/PlistBuddy
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

echo "==> AI Review インストーラ"
echo "    リポジトリ: $REPO"

# --- 0) 必要ファイルの存在チェック ---
[ -f "$TEMPLATE" ] || { echo "✗ テンプレートが見つかりません: $TEMPLATE"; exit 1; }
[ -f "$CLI_PATH" ] || { echo "✗ レビュー本体が見つかりません: $CLI_PATH"; exit 1; }

# --- 1) node を探す（do shell script は最小PATHで動くので絶対パスを埋め込む）---
NODE_BIN=""
for c in "$(command -v node 2>/dev/null || true)" \
         /opt/homebrew/bin/node /usr/local/bin/node \
         "$HOME/.volta/bin/node"; do
  if [ -n "$c" ] && [ -x "$c" ]; then NODE_BIN="$c"; break; fi
done
if [ -z "$NODE_BIN" ]; then
  cand="$(ls "$HOME"/.nvm/versions/node/*/bin/node 2>/dev/null | tail -1 || true)"
  [ -n "$cand" ] && [ -x "$cand" ] && NODE_BIN="$cand"
fi
if [ -z "$NODE_BIN" ]; then
  echo "✗ Node が見つかりませんでした。先に Node をインストールしてください。"
  echo "  例: https://nodejs.org/ の LTS版、または Homebrew で 'brew install node'"
  exit 1
fi
echo "    Node: $NODE_BIN"
case "$NODE_BIN" in
  *"/.nvm/"*|*"/.volta/"*)
    echo "    ⚠ nvm/volta の node を使用中。バージョン切替後に効かなくなったら install.command を再実行してください。";;
esac

# --- 2) 実行時依存（markdown-it）を用意 ---
if [ ! -d "$REPO/node_modules/markdown-it" ]; then
  NPM_BIN="$(dirname "$NODE_BIN")/npm"
  [ -x "$NPM_BIN" ] || NPM_BIN="$(command -v npm || true)"
  if [ -z "$NPM_BIN" ]; then
    echo "✗ npm が見つかりません。Node を入れ直すか、'npm install --omit=dev' を $REPO で手動実行してください。"
    exit 1
  fi
  echo "==> 必要な部品(markdown-it)を取得します（npm install）..."
  ( cd "$REPO" && "$NPM_BIN" install --omit=dev --no-audit --no-fund )
fi

# --- 3) AppleScript にパスを埋め込む（Bash置換: / や & を含んでも安全）---
SRC="$(cat "$TEMPLATE")"
SRC="${SRC//@@NODE_BIN@@/$NODE_BIN}"
SRC="${SRC//@@CLI_PATH@@/$CLI_PATH}"
TMP_DIR="$(mktemp -d)"
TMP_SCPT="$TMP_DIR/AI-Review.applescript"
printf '%s' "$SRC" > "$TMP_SCPT"

# --- 4) アプリをビルド ---
pkill -f "$APP_NAME.app/Contents/MacOS" 2>/dev/null || true
mkdir -p "$APP_DIR"
rm -rf "$APP"
osacompile -o "$APP" "$TMP_SCPT"
rm -rf "$TMP_DIR"

PLIST="$APP/Contents/Info.plist"
"$PB" -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null || "$PB" -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :LSUIElement bool true" "$PLIST" 2>/dev/null || "$PB" -c "Set :LSUIElement true" "$PLIST" 2>/dev/null || true
"$PB" -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :CFBundleDocumentTypes array" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string AllReviewableFiles" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Alternate" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.html" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:1 string public.content" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:2 string public.data" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:3 string public.item" "$PLIST"

# plist を書き換えたので署名を付け直す（ad-hoc）。これをしないと _CodeSignature が
# Info.plist と不整合になり、TCC(フルディスクアクセス)の同一性判定が不安定になる。
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP" 2>/dev/null || true

"$LSREG" -f "$APP"
echo "✓ 組み立て完了: $APP"

# --- 5) フルディスクアクセスの設定画面を開く ---
echo ""
echo "==> 最後に1回だけ「フルディスクアクセス」の許可が必要です。"
echo "    今から設定画面を開きます。リストに「${APP_NAME}」を［＋］で追加し、スイッチをONにしてください。"
echo "    （＋を押すと /Applications フォルダが開くので、$APP_NAME を選びます）"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles" 2>/dev/null || true
echo ""
echo "完了したら、cmux や Finder でHTMLを右クリック →「このアプリケーションで開く」→「${APP_NAME}」で使えます。"
