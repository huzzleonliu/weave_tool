#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMG_PATH=${1:-}

echo "[1/3] 构建生成 Rust 子 crate"
pushd "$ROOT_DIR/src/gen" >/dev/null
cargo build
popd >/dev/null

echo "[2/3] CMake 配置与生成"
pushd "$ROOT_DIR/qt" >/dev/null
cmake -S . -B build
cmake --build build -t gen_bindings
cmake --build build -j

echo "[3/3] 运行应用"
if [[ -n "$IMG_PATH" ]]; then
  ./build/picture_process_qt "$IMG_PATH"
else
  ./build/picture_process_qt
fi
popd >/dev/null


