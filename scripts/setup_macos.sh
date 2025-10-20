#!/usr/bin/env bash
set -euo pipefail

# macOS dependency setup for picture-process (Qt/QML + Rust)

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "[0/6] 平台检查"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "此脚本仅用于 macOS。当前平台: $(uname -s)" >&2
  exit 1
fi

echo "[1/6] 检查 Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  echo "未检测到 Homebrew，开始安装（非交互）..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "Homebrew 安装完成。"
fi

HOMEBREW_PREFIX=$(brew --prefix)
echo "Homebrew 前缀: ${HOMEBREW_PREFIX}"

echo "[2/6] 安装/检查 CMake"
if ! command -v cmake >/dev/null 2>&1; then
  brew install cmake
else
  echo "cmake 已安装: $(cmake --version | head -n1)"
fi

echo "[3/6] 安装/检查 Qt5 (qt@5)"
if ! brew list --versions qt@5 >/dev/null 2>&1; then
  brew install qt@5
else
  echo "qt@5 已安装: $(brew list --versions qt@5)"
fi

QT_PREFIX=$(brew --prefix qt@5)
QT_CMAKE_DIR="${QT_PREFIX}/lib/cmake"
echo "Qt 前缀: ${QT_PREFIX}"

echo "[4/6] 验证 Qt5 组件 (QuickControls2, Qml, Quick, Widgets) 的 CMake 配置"
missing_components=()
for comp in Qt5QuickControls2 Qt5Qml Qt5Quick Qt5Widgets Qt5Core Qt5Gui; do
  if [[ ! -d "${QT_CMAKE_DIR}/${comp}" ]]; then
    missing_components+=("${comp}")
  fi
done
if (( ${#missing_components[@]} > 0 )); then
  echo "缺少以下 Qt 组件的 CMake 配置目录: ${missing_components[*]}" >&2
  echo "请确认 Homebrew 的 qt@5 安装完整，或尝试：brew reinstall qt@5" >&2
  exit 2
fi

echo "[5/6] 安装/检查 Rust 工具链 (rustup/cargo)"
if ! command -v cargo >/dev/null 2>&1; then
  if ! command -v rustup >/dev/null 2>&1; then
    echo "未检测到 rustup，开始安装（非交互）..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
  else
    echo "已检测到 rustup，初始化默认工具链..."
    rustup default stable || true
  fi
else
  echo "cargo 已安装: $(cargo --version)"
fi

echo "[6/6] 安装/检查 rust_qt_binding_generator"
if ! command -v rust_qt_binding_generator >/dev/null 2>&1; then
  cargo install rust_qt_binding_generator
else
  echo "rust_qt_binding_generator 已安装: $(rust_qt_binding_generator --version 2>/dev/null || echo present)"
fi

cat <<EOF

完成。
后续构建时，如未全局链接 Qt，请为 CMake 指定前缀：
  -DCMAKE_PREFIX_PATH="${QT_CMAKE_DIR}"

若当前 shell 未加载 cargo，请执行：
  source "${HOME}/.cargo/env"

你可以现在运行：
  ${ROOT_DIR}/scripts/build_and_run_macos.sh /绝对路径/图片.png

EOF


