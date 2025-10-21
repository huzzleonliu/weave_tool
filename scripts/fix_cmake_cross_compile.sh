#!/bin/bash
# 修复CMake交叉编译问题的脚本
# 用法: ./scripts/fix_cmake_cross_compile.sh

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo -e "${BLUE}[修复] 解决CMake交叉编译问题${NC}"

# 清理构建目录
echo -e "${YELLOW}清理旧的构建文件...${NC}"
cd qt
if [ -d "build" ]; then
    rm -rf build
    echo -e "${GREEN}✓ 已清理构建目录${NC}"
fi

# 创建新的构建目录
mkdir -p build
cd build

# 创建简化的工具链文件
cat > windows-toolchain-simple.cmake << 'EOF'
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

# 禁用一些可能导致问题的功能
set(CMAKE_AUTOMOC OFF)
set(CMAKE_AUTORCC OFF)
set(CMAKE_AUTOUIC OFF)
EOF

# 创建简化的CMakeLists.txt
cat > ../CMakeLists_simple.txt << 'EOF'
cmake_minimum_required(VERSION 3.16)
project(picture_process_qt LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

# 手动处理Qt
find_package(Qt5 5.15 COMPONENTS Core Gui Widgets Qml Quick REQUIRED)

# Rust静态库路径
set(GEN_RS_GEN ${CMAKE_CURRENT_SOURCE_DIR}/../src/gen/target/x86_64-pc-windows-gnu/release/libpicture_process_generated.a)

# 检查Rust静态库是否存在
if(NOT EXISTS ${GEN_RS_GEN})
    message(FATAL_ERROR "Rust静态库不存在: ${GEN_RS_GEN}")
endif()

# 手动添加源文件
set(SOURCES
    main.cpp
    qml.qrc
)

# 创建可执行文件
add_executable(picture_process_qt ${SOURCES})

# 手动处理Qt资源
qt5_add_resources(QML_RCS qml.qrc)
target_sources(picture_process_qt PRIVATE ${QML_RCS})

# 链接库
target_link_libraries(picture_process_qt
    Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Qml Qt5::Quick
    ${GEN_RS_GEN}
)

# 设置输出目录
set_target_properties(picture_process_qt PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)
EOF

echo -e "${BLUE}使用简化的CMakeLists.txt进行配置...${NC}"

# 使用简化的配置
cmake -DCMAKE_TOOLCHAIN_FILE=windows-toolchain-simple.cmake \
      -DCMAKE_BUILD_TYPE=Release \
      -S .. -B .

echo -e "${GREEN}✓ CMake配置完成${NC}"

# 尝试构建
echo -e "${BLUE}开始构建...${NC}"
make -j$(nproc) || {
    echo -e "${RED}make构建失败，尝试使用单线程构建...${NC}"
    make || {
        echo -e "${RED}构建失败，请检查错误信息${NC}"
        exit 1
    }
}

echo -e "${GREEN}✓ 构建完成${NC}"

# 查找生成的可执行文件
if [ -f "picture_process_qt.exe" ]; then
    echo -e "${GREEN}✓ 成功生成: $(pwd)/picture_process_qt.exe${NC}"
    cp picture_process_qt.exe "$ROOT_DIR/"
    echo -e "${GREEN}✓ 已复制到项目根目录${NC}"
else
    echo -e "${RED}错误: 未找到生成的可执行文件${NC}"
    exit 1
fi

cd "$ROOT_DIR"
echo -e "${GREEN}🎉 修复完成！${NC}"
