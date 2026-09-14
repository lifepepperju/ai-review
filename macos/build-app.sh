#!/usr/bin/env bash
# Build "AI Review.app" into ~/Applications so it appears in macOS "Open With"
# (cmux / Finder: 右クリック → このアプリケーションで開く → AI Review).
#
# After building, you MUST grant the app Full Disk Access once:
#   System Settings → Privacy & Security → Full Disk Access → + → ~/Applications/AI Review.app
# Otherwise it cannot read files under ~/Documents (macOS TCC / EPERM).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/AI-Review.applescript"
APP="$HOME/Applications/AI Review.app"
PLIST="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

pkill -f "AI Review.app/Contents/MacOS" 2>/dev/null || true
mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" "$SRC"

"$PB" -c "Set :CFBundleIdentifier com.example.aireview" "$PLIST" 2>/dev/null || true
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

"$LSREG" -f "$APP"
echo "Built: $APP"
echo "次に Full Disk Access を一度だけ許可してください（上記コメント参照）。"
