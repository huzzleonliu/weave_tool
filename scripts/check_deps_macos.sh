#!/usr/bin/env bash
set -euo pipefail

# 简要: 检查 macOS 下构建所需依赖是否满足
# - Rust 工具链: cargo, rustc
# - rust_qt_binding_generator (可选但建议)
# - CMake >= 3.16
# - Qt5 组件 (通过 Homebrew 安装: brew install qt@5)
# - C/C++ 编译器: clang++, make 或 ninja

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; }

check_cmd() { if command -v "$1" >/dev/null 2>&1; then pass "$1: $(command -v "$1")"; return 0; else fail "$1 未找到"; return 1; fi; }

ok=1

echo "== 检查 Rust 工具链 =="
check_cmd cargo || ok=0
check_cmd rustc || ok=0

echo "== 检查 rust_qt_binding_generator (可选) =="
if check_cmd rust_qt_binding_generator; then :; else warn "未检测到 rust_qt_binding_generator，建议: cargo install rust_qt_binding_generator"; fi

echo "== 检查 CMake (>=3.16) =="
if check_cmd cmake; then
  ver=$(cmake --version | head -n1 | awk '{print $3}')
  major=$(echo "$ver" | cut -d. -f1)
  minor=$(echo "$ver" | cut -d. -f2)
  if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 16 ]; }; then
    warn "CMake 版本 $ver < 3.16，建议升级"
  fi
else
  ok=0
fi

echo "== 检查编译工具链 =="
check_cmd clang++ || ok=0
if check_cmd make; then :; else warn "未找到 make；如使用 Ninja 请安装 ninja 并在 CMake 中指定"; fi

echo "== 检查 Qt5 (brew) =="
if check_cmd brew; then
  if brew ls --versions qt@5 >/dev/null 2>&1; then
    pass "Homebrew 已安装 qt@5"
    # 提示 CMAKE_PREFIX_PATH
    qt_prefix=$(brew --prefix qt@5 2>/dev/null || true)
    if [ -n "$qt_prefix" ]; then
      pass "建议在构建前设置: export CMAKE_PREFIX_PATH=$qt_prefix"
    fi
  else
    warn "未检测到 qt@5 (Homebrew)。安装: brew install qt@5"
  fi
else
  warn "未检测到 Homebrew；请确保 Qt5 已正确安装，并在 CMake 时提供路径"
fi

echo
if [ "$ok" -eq 1 ]; then
  echo -e "${GREEN}依赖检查完成（如有 WARN 请按提示处理）${NC}"
  exit 0
else
  echo -e "${YELLOW}依赖检查存在问题，请根据上方提示安装缺失组件${NC}"
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

ok() { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }
fail() { echo "[ERR] $1"; exit 1; }

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

# Rust
check_cmd cargo "参见 https://rustup.rs 安装 rustup 与 Rust 工具链" || missing=1
check_cmd rustc || missing=1

# CMake
check_cmd cmake "brew install cmake" || missing=1

# Qt (建议通过 brew 安装 qt@5)
if command -v qmake >/dev/null 2>&1 || command -v qmake-qt5 >/dev/null 2>&1; then
	ok "qmake 可用"
else
	warn "未检测到 qmake。建议: brew install qt@5 并设置 CMAKE_PREFIX_PATH"
	missing=1
fi

# CMake find Qt
if cmake -P /dev/stdin <<'EOF' >/dev/null 2>&1
message(STATUS "Probing Qt5...")
find_package(Qt5 5.15 COMPONENTS Core Gui Widgets Qml Quick QmlModels QuickControls2 REQUIRED)
message(STATUS "Qt5 FOUND")
EOF
then
	ok "CMake 可找到 Qt5"
else
	warn "CMake 未能找到 Qt5，请设置: export CMAKE_PREFIX_PATH=$(brew --prefix qt@5)"
	missing=1
fi

# rust_qt_binding_generator
if command -v rust_qt_binding_generator >/dev/null 2>&1; then
	ok "rust_qt_binding_generator 已安装"
else
	warn "rust_qt_binding_generator 未安装：cargo install rust_qt_binding_generator"
fi

if [[ $missing -eq 0 ]]; then

echo "依赖检查通过。"
	exit 0
else
	fail "依赖检查未通过，请根据上方提示安装缺失组件。"
fi
