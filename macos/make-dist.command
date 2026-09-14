#!/usr/bin/env bash
# 配布ZIPを作る（配る人=宇佐見さん用）。ダブルクリックで実行。
# node_modules / dist / .git / *.vsix 等を除いた軽量パッケージを Output/ に作成します。
#
# 出力先・ZIP名・中のフォルダ名はすべて ASCII に固定。
# （日本語のフォルダ/ファイル名は macOS の NFC/NFD 正規化でシェルの find/glob/zip が
#  取りこぼし、中身が入らないZIPができることがあるため。Slack/解凍の文字化け対策にもなる）
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../ai-review-comments/macos
REPO="$(cd "$HERE/.." && pwd)"                          # .../ai-review-comments
OUT_BASE="/Users/junusami/Documents/Claude仕事/Output/ai-review-distribution"
KIT="ai-review-setup-kit"                               # ASCII固定
STAGE="$OUT_BASE/$KIT"
ZIP="$OUT_BASE/$KIT.zip"
GUIDE="$OUT_BASE/README.html"

echo "==> 配布パッケージを作成します"
[ -d "$REPO/cli" ] || { echo "✗ リポジトリが見つかりません: $REPO"; exit 1; }

mkdir -p "$OUT_BASE"
rm -rf "$STAGE" "$ZIP"
mkdir -p "$STAGE/ai-review-comments"

# 実行に不要な開発物・個人ログ・gitを除外してコピー
rsync -a \
  --exclude 'node_modules/' \
  --exclude 'dist/' \
  --exclude '.git/' \
  --exclude '*.vsix' \
  --exclude '*.log' \
  --exclude '.DS_Store' \
  --exclude '.ai-review/' \
  "$REPO/" "$STAGE/ai-review-comments/"

# 手順書を同梱（READMEとして。GUIDE が無ければスキップ）
[ -f "$GUIDE" ] && cp "$GUIDE" "$STAGE/README.html"

# コピー結果を検証（空・不足なら中止）
FILES="$(find "$STAGE/ai-review-comments" -type f | wc -l | tr -d ' ')"
echo "    コピーしたファイル数: $FILES"
[ "$FILES" -ge 5 ] || { echo "✗ コピーが不十分です（$FILES 件）。中止します。"; exit 1; }

# ZIP化（cd して相対パスで固める）
( cd "$OUT_BASE" && zip -r -q "$KIT.zip" "$KIT" )

# ZIP検証
ZSIZE="$(stat -f%z "$ZIP" 2>/dev/null || echo 0)"
ZENTRIES="$(unzip -l "$ZIP" 2>/dev/null | tail -1 | awk '{print $2}')"
echo "    ZIPサイズ: $ZSIZE bytes / 収録: $ZENTRIES エントリ"

rm -rf "$STAGE"

echo "✓ 配布ZIP: $ZIP"
echo "   このZIPをメンバーに渡してください（Slack等）。"
open "$OUT_BASE" 2>/dev/null || true
