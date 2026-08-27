#!/bin/bash
# 포맷터(계좌·카드·신분번호) 자체 점검. 로직 고친 뒤 반드시 한 번 돌릴 것.
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Volumes/Workstation/Applications/Xcode.app/Contents/Developer
OUT=$(mktemp -d)
cp Tools/format_check.swift "$OUT/main.swift"
xcrun swiftc -o "$OUT/check" Sources/Format/*.swift "$OUT/main.swift"
"$OUT/check"
