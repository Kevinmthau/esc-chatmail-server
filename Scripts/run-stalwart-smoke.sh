#!/bin/zsh
set -euo pipefail

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/tmp/clang-module-cache}"
SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-/tmp/swiftpm-module-cache}"

export DEVELOPER_DIR
export CLANG_MODULE_CACHE_PATH
export SWIFTPM_MODULECACHE_OVERRIDE

swift run ESCChatmailStalwartSmoke
