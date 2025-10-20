#!/usr/bin/env bash
set -euo pipefail

# macOS one-click build and run for picture-process

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMG_PATH=${1:-}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "此脚本仅用于 macOS。当前平台: $(uname -s)" >&2
  exit 1
fi

if [[ -f "${HOME}/.cargo/env" ]]; then
  # shellcheck source=/dev/null
  source "${HOME}/.cargo/env"
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "缺少 cmake，请先运行 scripts/setup_macos.sh 安装依赖。" >&2
  exit 2
fi

if ! command -v rust_qt_binding_generator >/dev/null 2>&1; then
  echo "缺少 rust_qt_binding_generator，请先运行 scripts/setup_macos.sh 安装依赖。" >&2
  exit 2
fi

if ! command -v brew >/dev/null 2>&1 || ! brew list --versions qt@5 >/dev/null 2>&1; then
  echo "未检测到 Homebrew 的 qt@5，请先运行 scripts/setup_macos.sh 安装依赖。" >&2
  exit 2
fi

QT_PREFIX=$(brew --prefix qt@5)
QT_CMAKE_DIR="${QT_PREFIX}/lib/cmake"
export CMAKE_PREFIX_PATH="${QT_CMAKE_DIR}:${CMAKE_PREFIX_PATH:-}"

echo "[1/3] 构建生成 Rust 子 crate"
pushd "${ROOT_DIR}/src/gen" >/dev/null
cargo build
popd >/dev/null

echo "[2/3] CMake 配置与生成 (macOS + Qt5)"
pushd "${ROOT_DIR}/qt" >/dev/null
cmake -S . -B build -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}"
cmake --build build -t gen_bindings
cmake --build build -j

echo "[3/3] 运行应用"
APP_BIN="./build/picture_process_qt"
if [[ -n "${IMG_PATH}" ]]; then
  "${APP_BIN}" "${IMG_PATH}"
else
  "${APP_BIN}"
fi
popd >/dev/null


