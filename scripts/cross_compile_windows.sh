#!/bin/bash
# 交叉编译脚本：从Linux编译生成64位Windows可执行文件
# 用法: ./scripts/cross_compile_windows.sh

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录的上级目录作为项目根目录
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo -e "${BLUE}[交叉编译] 开始构建64位Windows可执行文件${NC}"

# 检查必要的工具
echo -e "${BLUE}[0/5] 检查交叉编译环境${NC}"

# 检查Rust工具链
if ! command -v rustup &> /dev/null; then
    echo -e "${RED}错误: 未找到rustup，请先安装Rust${NC}"
    exit 1
fi

# 检查是否已安装Windows目标
if ! rustup target list --installed | grep -q "x86_64-pc-windows-gnu"; then
    echo -e "${YELLOW}安装Windows目标工具链...${NC}"
    rustup target add x86_64-pc-windows-gnu
fi

# 检查交叉编译工具链
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo -e "${RED}错误: 未找到x86_64-w64-mingw32-gcc，请安装mingw-w64交叉编译工具链${NC}"
    echo -e "${YELLOW}在Arch Linux上运行: sudo pacman -S mingw-w64-gcc${NC}"
    echo -e "${YELLOW}在Ubuntu/Debian上运行: sudo apt install gcc-mingw-w64-x86-64${NC}"
    exit 1
fi

# 检查CMake
if ! command -v cmake &> /dev/null; then
    echo -e "${RED}错误: 未找到cmake，请先安装CMake${NC}"
    exit 1
fi

# 检查Qt5开发工具（用于交叉编译）
if ! command -v qmake &> /dev/null; then
    echo -e "${YELLOW}警告: 未找到qmake，Qt交叉编译可能需要额外配置${NC}"
fi

echo -e "${GREEN}✓ 交叉编译环境检查完成${NC}"

# 配置Rust交叉编译环境
echo -e "${BLUE}[1/5] 配置Rust交叉编译环境${NC}"
export CC_x86_64_pc_windows_gnu=x86_64-w64-mingw32-gcc
export CXX_x86_64_pc_windows_gnu=x86_64-w64-mingw32-g++
export AR_x86_64_pc_windows_gnu=x86_64-w64-mingw32-ar
export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc

# 创建.cargo/config.toml文件来配置交叉编译
mkdir -p .cargo
cat > .cargo/config.toml << EOF
[target.x86_64-pc-windows-gnu]
linker = "x86_64-w64-mingw32-gcc"
EOF

echo -e "${GREEN}✓ Rust交叉编译环境配置完成${NC}"

# 构建Rust生成子crate
echo -e "${BLUE}[2/5] 构建Rust生成子crate (Windows目标)${NC}"
cd src/gen
cargo build --target x86_64-pc-windows-gnu --release
cd "$ROOT_DIR"

echo -e "${GREEN}✓ Rust子crate构建完成${NC}"

# 准备Qt交叉编译环境
echo -e "${BLUE}[3/5] 准备Qt交叉编译环境${NC}"
cd qt

# 清理旧的构建目录
if [ -d "build" ]; then
    echo -e "${YELLOW}清理旧的构建目录...${NC}"
    rm -rf build
fi

# 创建构建目录
mkdir -p build
cd build

# 设置交叉编译环境变量
export PKG_CONFIG_PATH=""
export PKG_CONFIG_LIBDIR=""
export PKG_CONFIG_SYSROOT_DIR=""

# 查找Windows版本的Qt（如果可用）
WINDOWS_QT_PATH=""
if [ -d "/usr/x86_64-w64-mingw32/lib/qt5" ]; then
    WINDOWS_QT_PATH="/usr/x86_64-w64-mingw32/lib/qt5"
elif [ -d "/usr/lib/mingw-w64-x86_64-qt5" ]; then
    WINDOWS_QT_PATH="/usr/lib/mingw-w64-x86_64-qt5"
fi

if [ -n "$WINDOWS_QT_PATH" ]; then
    echo -e "${GREEN}找到Windows Qt路径: $WINDOWS_QT_PATH${NC}"
    export CMAKE_PREFIX_PATH="$WINDOWS_QT_PATH"
else
    echo -e "${YELLOW}警告: 未找到Windows版本的Qt，将尝试使用系统Qt进行交叉编译${NC}"
fi

# 配置CMake进行交叉编译
echo -e "${BLUE}[4/5] 配置CMake交叉编译${NC}"

# 创建工具链文件
cat > windows-toolchain.cmake << 'EOF'
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# 指定交叉编译器
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)

# 指定工具链程序
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)
set(CMAKE_AR x86_64-w64-mingw32-ar)
set(CMAKE_RANLIB x86_64-w64-mingw32-ranlib)
set(CMAKE_STRIP x86_64-w64-mingw32-strip)

# 查找库的路径
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# 设置Windows特定选项
set(CMAKE_EXECUTABLE_SUFFIX .exe)
set(CMAKE_SHARED_LIBRARY_PREFIX "")
set(CMAKE_SHARED_LIBRARY_SUFFIX .dll)
set(CMAKE_STATIC_LIBRARY_PREFIX lib)
set(CMAKE_STATIC_LIBRARY_SUFFIX .a)
EOF

# 运行CMake配置
echo -e "${YELLOW}使用交叉编译专用的CMakeLists.txt...${NC}"

# 复制交叉编译专用的CMakeLists.txt
cp ../CMakeLists_cross.txt ../CMakeLists.txt.backup
cp ../CMakeLists_cross.txt ../CMakeLists.txt

if [ -n "$WINDOWS_QT_PATH" ]; then
    cmake -DCMAKE_TOOLCHAIN_FILE=windows-toolchain.cmake \
          -DCMAKE_PREFIX_PATH="$WINDOWS_QT_PATH" \
          -DCMAKE_BUILD_TYPE=Release \
          -S .. -B .
else
    cmake -DCMAKE_TOOLCHAIN_FILE=windows-toolchain.cmake \
          -DCMAKE_BUILD_TYPE=Release \
          -S .. -B .
fi

echo -e "${GREEN}✓ CMake配置完成${NC}"

# 构建项目
echo -e "${BLUE}[5/5] 构建Qt应用程序${NC}"

# 尝试生成绑定
cmake --build . --target gen_bindings || echo -e "${YELLOW}警告: 绑定生成失败，继续构建...${NC}"

# 使用make而不是cmake --build来避免交叉编译问题
echo -e "${YELLOW}使用make进行构建以避免交叉编译问题...${NC}"
make -j$(nproc) || {
    echo -e "${RED}make构建失败，尝试使用ninja...${NC}"
    if command -v ninja &> /dev/null; then
        ninja || {
            echo -e "${RED}构建失败，请检查错误信息${NC}"
            exit 1
        }
    else
        echo -e "${RED}构建失败，请检查错误信息${NC}"
        exit 1
    fi
}

echo -e "${GREEN}✓ 构建完成${NC}"

# 查找生成的可执行文件
EXE_PATH=""
if [ -f "picture_process_qt.exe" ]; then
    EXE_PATH="$(pwd)/picture_process_qt.exe"
elif [ -f "Release/picture_process_qt.exe" ]; then
    EXE_PATH="$(pwd)/Release/picture_process_qt.exe"
fi

if [ -n "$EXE_PATH" ] && [ -f "$EXE_PATH" ]; then
    echo -e "${GREEN}✓ 成功生成Windows可执行文件: $EXE_PATH${NC}"
    
    # 显示文件信息
    echo -e "${BLUE}文件信息:${NC}"
    ls -lh "$EXE_PATH"
    file "$EXE_PATH"
    
    # 复制到项目根目录
    cp "$EXE_PATH" "$ROOT_DIR/"
    echo -e "${GREEN}✓ 可执行文件已复制到项目根目录${NC}"
else
    echo -e "${RED}错误: 未找到生成的可执行文件${NC}"
    echo -e "${YELLOW}请检查构建日志以获取更多信息${NC}"
    exit 1
fi

cd "$ROOT_DIR"

# 恢复原始CMakeLists.txt
if [ -f "qt/CMakeLists.txt.backup" ]; then
    mv qt/CMakeLists.txt.backup qt/CMakeLists.txt
    echo -e "${GREEN}✓ 已恢复原始CMakeLists.txt${NC}"
fi

# 清理临时文件
rm -f .cargo/config.toml

echo -e "${GREEN}🎉 交叉编译完成！${NC}"
echo -e "${BLUE}生成的文件: $(pwd)/picture_process_qt.exe${NC}"
echo -e "${YELLOW}注意: 在Windows上运行此exe文件需要相应的DLL文件${NC}"
echo -e "${YELLOW}可以使用以下命令检查依赖: x86_64-w64-mingw32-objdump -p picture_process_qt.exe | grep DLL${NC}"
