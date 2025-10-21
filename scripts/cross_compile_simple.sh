#!/bin/bash
# 简化的交叉编译脚本 - 绕过CMake问题
# 用法: ./scripts/cross_compile_simple.sh

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo -e "${BLUE}[简化交叉编译] 绕过CMake问题，直接编译${NC}"

# 检查环境
echo -e "${BLUE}[1/4] 检查环境${NC}"
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo -e "${RED}错误: 未找到交叉编译器${NC}"
    exit 1
fi

if ! command -v rustup &> /dev/null; then
    echo -e "${RED}错误: 未找到rustup${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 环境检查完成${NC}"

# 构建Rust部分
echo -e "${BLUE}[2/4] 构建Rust静态库${NC}"
cd src/gen

# 设置交叉编译环境
export CC_x86_64_pc_windows_gnu=x86_64-w64-mingw32-gcc
export CXX_x86_64_pc_windows_gnu=x86_64-w64-mingw32-g++
export AR_x86_64_pc_windows_gnu=x86_64-w64-mingw32-ar
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc

# 创建.cargo/config.toml
mkdir -p .cargo
cat > .cargo/config.toml << EOF
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
EOF

# 构建Rust库
cargo build --target x86_64-pc-windows-gnu --release

cd "$ROOT_DIR"
echo -e "${GREEN}✓ Rust静态库构建完成${NC}"

# 检查生成的库文件
RUST_LIB="$ROOT_DIR/src/gen/target/x86_64-pc-windows-gnu/release/libpicture_process_generated.a"
if [ ! -f "$RUST_LIB" ]; then
    echo -e "${RED}错误: Rust静态库未生成${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 找到Rust静态库: $RUST_LIB${NC}"

# 手动编译C++部分
echo -e "${BLUE}[3/4] 手动编译C++部分${NC}"
cd qt

# 检查源文件
if [ ! -f "main.cpp" ]; then
    echo -e "${RED}错误: 未找到main.cpp${NC}"
    exit 1
fi

# 创建简化的编译脚本
cat > compile_manual.sh << 'EOF'
#!/bin/bash
set -e

# 设置编译器
CC=x86_64-w64-mingw32-gcc
CXX=x86_64-w64-mingw32-g++

# 查找Qt库路径
QT_PATHS=(
    "/usr/x86_64-w64-mingw32/lib/qt5"
    "/usr/lib/mingw-w64-x86_64-qt5"
    "/usr/x86_64-w64-mingw32/lib"
)

QT_INCLUDE=""
QT_LIBS=""

for path in "${QT_PATHS[@]}"; do
    if [ -d "$path" ]; then
        QT_INCLUDE="$path/include"
        QT_LIBS="$path/lib"
        echo "找到Windows Qt路径: $path"
        break
    fi
done

if [ -z "$QT_INCLUDE" ]; then
    echo "警告: 未找到Windows Qt，使用系统Qt5"
    QT_INCLUDE="/usr/include/qt"
    QT_LIBS="/usr/lib"
fi

# 编译参数
INCLUDES="-I$QT_INCLUDE -I$QT_INCLUDE/QtCore -I$QT_INCLUDE/QtGui -I$QT_INCLUDE/QtWidgets -I$QT_INCLUDE/QtQml -I$QT_INCLUDE/QtQuick -I$QT_INCLUDE/QtQml/5.15.0 -I$QT_INCLUDE/QtCore/5.15.0"

# 添加更多可能的Qt路径
for subdir in QtCore QtGui QtWidgets QtQml QtQuick; do
    if [ -d "$QT_INCLUDE/$subdir" ]; then
        INCLUDES="$INCLUDES -I$QT_INCLUDE/$subdir"
    fi
    if [ -d "$QT_INCLUDE/$subdir/5.15.0" ]; then
        INCLUDES="$INCLUDES -I$QT_INCLUDE/$subdir/5.15.0"
    fi
done

LIBS="-L$QT_LIBS -lQt5Core -lQt5Gui -lQt5Widgets -lQt5Qml -lQt5Quick"

# 检查是否有生成的C++文件
if [ -f "generated/viewer_cxx.h" ]; then
    INCLUDES="$INCLUDES -I./generated"
    echo "找到生成的C++头文件"
else
    echo "警告: 未找到生成的C++头文件，可能需要先运行绑定生成器"
fi

# 编译主程序
echo "编译主程序..."
echo "使用包含路径: $INCLUDES"
echo "使用库路径: $LIBS"

$CXX -std=c++17 $INCLUDES -o picture_process_qt.exe main.cpp $LIBS ../src/gen/target/x86_64-pc-windows-gnu/release/libpicture_process_generated.a -static-libgcc -static-libstdc++ -DQT_WIDGETS_LIB -DQT_QML_LIB -DQT_QUICK_LIB

echo "编译完成: picture_process_qt.exe"
EOF

chmod +x compile_manual.sh
./compile_manual.sh

cd "$ROOT_DIR"
echo -e "${GREEN}✓ C++编译完成${NC}"

# 检查生成的文件
echo -e "${BLUE}[4/4] 检查生成的文件${NC}"
EXE_PATH="$ROOT_DIR/qt/picture_process_qt.exe"

if [ -f "$EXE_PATH" ]; then
    echo -e "${GREEN}✓ 成功生成Windows可执行文件: $EXE_PATH${NC}"
    
    # 复制到项目根目录
    cp "$EXE_PATH" "$ROOT_DIR/"
    echo -e "${GREEN}✓ 已复制到项目根目录${NC}"
    
    # 显示文件信息
    echo -e "${BLUE}文件信息:${NC}"
    ls -lh "$ROOT_DIR/picture_process_qt.exe"
    file "$ROOT_DIR/picture_process_qt.exe"
    
    echo -e "${GREEN}🎉 简化交叉编译完成！${NC}"
    echo -e "${BLUE}生成的文件: $ROOT_DIR/picture_process_qt.exe${NC}"
else
    echo -e "${RED}错误: 未找到生成的可执行文件${NC}"
    exit 1
fi

# 清理临时文件
rm -f .cargo/config.toml
rm -f qt/compile_manual.sh

echo -e "${YELLOW}注意: 这是一个简化版本，可能缺少一些Qt功能${NC}"
echo -e "${YELLOW}如果需要完整功能，请尝试安装Windows版本的Qt5${NC}"
