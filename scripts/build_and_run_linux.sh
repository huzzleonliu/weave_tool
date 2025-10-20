#!/usr/bin/env bash
set -euo pipefail

# 用法: ./scripts/build_and_run_linux.sh [/绝对路径/图片.png]

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMG_PATH=${1:-}

echo "[0/3] 可选依赖检查 (跳过失败不终止)"
if "$ROOT_DIR/scripts/check_deps_linux.sh"; then
  :
else
  echo "依赖检查有警告，尝试继续构建..."
fi

echo "[1/3] 构建 Rust 生成子 crate"
pushd "$ROOT_DIR/src/gen" >/dev/null
cargo build
popd >/dev/null

echo "[2/3] 配置并构建 Qt/CMake 工程"
pushd "$ROOT_DIR/qt" >/dev/null
 # 若缓存来自不同源路径，清理 build 目录以避免 CMake 源不匹配错误
if [[ -f build/CMakeCache.txt ]]; then
  cached_src=$(grep -E '^CMAKE_HOME_DIRECTORY:' build/CMakeCache.txt | sed -E 's/^[^=]+=//')
  if [[ -n "$cached_src" && "$cached_src" != "$PWD" ]]; then
    echo "检测到旧的 CMake 缓存来自: $cached_src，与当前源目录不一致，清理 qt/build..."
    rm -rf build
  fi
fi

cmake -S . -B build
cmake --build build -t gen_bindings || echo "生成绑定失败或跳过，若已存在生成文件可忽略"
cmake --build build -j

echo "[3/3] 运行应用"
if [[ -n "${IMG_PATH}" ]]; then
  ./build/picture_process_qt "${IMG_PATH}"
else
  ./build/picture_process_qt
fi
popd >/dev/null

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMG_PATH=${1:-}

# 依赖快速检查（不强制）
if [[ -x "$ROOT_DIR/scripts/check_deps_linux.sh" ]]; then
	bash "$ROOT_DIR/scripts/check_deps_linux.sh" || echo "[WARN] 可继续尝试构建，但部分依赖可能缺失。"
fi

echo "[1/3] 构建生成 Rust 子 crate"
pushd "$ROOT_DIR/src/gen" >/dev/null
cargo build
popd >/dev/null

echo "[2/3] CMake 配置与生成"
pushd "$ROOT_DIR/qt" >/dev/null
cmake -S . -B build
cmake --build build -t gen_bindings || echo "[WARN] 绑定生成失败或跳过，若已生成可忽略"
cmake --build build -j

echo "[3/3] 运行应用"
if [[ -n "$IMG_PATH" ]]; then
	./build/picture_process_qt "$IMG_PATH"
else
	./build/picture_process_qt
fi
popd >/dev/null
