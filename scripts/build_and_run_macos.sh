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
# 若缓存来自不同源路径，清理 build 目录以避免 CMake 源不匹配错误
if [[ -f build/CMakeCache.txt ]]; then
  cached_src=$(grep -E '^CMAKE_HOME_DIRECTORY:' build/CMakeCache.txt | sed -E 's/^[^=]+=//')
  if [[ -n "$cached_src" && "$cached_src" != "$PWD" ]]; then
    echo "检测到旧的 CMake 缓存来自: $cached_src，与当前源目录不一致，清理 qt/build..."
    rm -rf build
  fi
fi

cmake -S . -B build -DCMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}"
cmake --build build -t gen_bindings || echo "生成绑定失败或跳过，若已存在生成文件可忽略"
cmake --build build -j

echo "[3/3] 运行应用"
APP_BIN="./build/picture_process_qt"
if [[ -n "${IMG_PATH}" ]]; then
  "${APP_BIN}" "${IMG_PATH}"
else
  "${APP_BIN}"
fi
popd >/dev/null


