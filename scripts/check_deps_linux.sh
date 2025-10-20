#!/usr/bin/env bash
set -euo pipefail

# 简要: 检查 Linux 下构建所需依赖是否满足
# - Rust 工具链: cargo, rustc
# - rust_qt_binding_generator (可选但建议)
# - CMake >= 3.16
# - Qt5 组件: Core, Gui, Widgets, Qml, Quick, QmlModels, QuickControls2
# - C/C++ 编译器: g++, make

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "$1: $(command -v "$1")"
    return 0
  else
    fail "$1 未找到"
    return 1
  fi
}

ok=1

echo "== 检查 Rust 工具链 =="
check_cmd cargo || ok=0
check_cmd rustc || ok=0

echo "== 检查 rust_qt_binding_generator (可选) =="
if check_cmd rust_qt_binding_generator; then
  :
else
  warn "未检测到 rust_qt_binding_generator。构建将跳过自动生成，可在 Qt 构建中手动执行 gen_bindings。建议: cargo install rust_qt_binding_generator"
fi

echo "== 检查 CMake (>=3.16) =="
if check_cmd cmake; then
  ver=$(cmake --version | head -n1 | awk '{print $3}')
  # 版本比较（简单比较主次版本）
  major=$(echo "$ver" | cut -d. -f1)
  minor=$(echo "$ver" | cut -d. -f2)
  if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 16 ]; }; then
    warn "CMake 版本 $ver < 3.16，建议升级"
  fi
else
  ok=0
fi

echo "== 检查编译工具链 =="
check_cmd g++ || ok=0
check_cmd make || warn "未找到 make（部分环境用 ninja），若使用 Ninja 请安装 ninja 且在 CMake 中指定"

echo "== 检查 Qt5 组件 (qmake/qtpaths/Qt5Config) =="
if check_cmd qmake; then
  qtvers=$(qmake -query QT_VERSION 2>/dev/null || true)
  [ -n "$qtvers" ] && pass "Qt 版本: $qtvers" || warn "无法从 qmake 获取 Qt 版本"
else
  warn "未找到 qmake，可改用 qtpaths/qtchooser 或 CMake 自检；请确保已安装 Qt5 开发包"
fi

if check_cmd qtpaths; then
  :
else
  warn "未找到 qtpaths（某些发行版提供于 qtbase5-dev-tools）"
fi

echo "== 尝试通过 pkg-config 检测部分 Qt5 模块 =="
missing_qt=0
for pkg in Qt5Core Qt5Gui Qt5Widgets Qt5Qml Qt5Quick Qt5QmlModels Qt5QuickControls2; do
  if pkg-config --exists $pkg 2>/dev/null; then
    pass "$pkg 存在"
  else
    warn "$pkg 缺失"
    missing_qt=1
  fi
done

echo
if [ "$ok" -eq 1 ] && [ "$missing_qt" -eq 0 ]; then
  echo -e "${GREEN}依赖检查通过${NC}"
  exit 0
else
  echo -e "${YELLOW}依赖检查存在问题，请根据上方提示安装缺失组件${NC}"
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

ok() { echo -e "[OK] $1"; }
warn() { echo -e "[WARN] $1"; }
fail() { echo -e "[ERR] $1"; exit 1; }

check_cmd() {
	local name=$1
	local hint=${2:-}
	if command -v "$name" >/dev/null 2>&1; then
		ok "$name 已安装"
	else
		warn "$name 未找到"
		if [[ -n "$hint" ]]; then echo "  安装提示: $hint"; fi
		return 1
	fi
}

missing=0

# Rust toolchain
check_cmd cargo "参见 https://rustup.rs 安装 rustup 与 Rust 工具链" || missing=1
check_cmd rustc || missing=1

# CMake
check_cmd cmake "使用发行版包管理器安装，例如: sudo pacman -S cmake 或 sudo apt install cmake" || missing=1

# Qt5 (core components)
# 检查 qmake 或 qmake-qt5 或 qtchooser
if command -v qmake >/dev/null 2>&1 || command -v qmake-qt5 >/dev/null 2>&1 || command -v qtchooser >/dev/null 2>&1; then
	ok "Qt 构建工具可用 (qmake/qtchooser)"
else
	warn "未检测到 qmake/qtchooser。请安装 Qt5 开发包 (包含 Core/Gui/Widgets/Qml/Quick/QuickControls2)"
	missing=1
fi

# Qt5 cmake packages
# 尝试通过 cmake 查找 Qt5 包
if cmake -P /dev/stdin <<'EOF' >/dev/null 2>&1
message(STATUS "Probing Qt5...")
find_package(Qt5 5.12 COMPONENTS Core Gui Widgets Qml Quick QmlModels QuickControls2 REQUIRED)
message(STATUS "Qt5 FOUND")
EOF
then
	ok "CMake 可找到 Qt5 组件"
else
	warn "CMake 未能找到所需 Qt5 组件。请确保已安装并正确设置 CMAKE_PREFIX_PATH 或 QTDIR"
	missing=1
fi

# rust_qt_binding_generator
if command -v rust_qt_binding_generator >/dev/null 2>&1; then
	ok "rust_qt_binding_generator 已安装"
else
	warn "rust_qt_binding_generator 未安装：可执行 cargo install rust_qt_binding_generator"
fi

# ImageMagick/PNG 工具非必需，仅用于调试
if command -v file >/dev/null 2>&1; then ok "file 已安装 (可选)"; fi

if [[ $missing -eq 0 ]]; then

echo "依赖检查通过。"
	exit 0
else
	fail "依赖检查未通过，请根据上方提示安装缺失组件。"
fi
