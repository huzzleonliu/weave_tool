#!/bin/bash
# 设置交叉编译环境的辅助脚本
# 用法: ./scripts/setup_cross_compile_env.sh

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[环境设置] 配置Windows交叉编译环境${NC}"

# 检测操作系统
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${GREEN}检测到Linux系统${NC}"
    
    # 检查包管理器
    if command -v pacman &> /dev/null; then
        echo -e "${BLUE}检测到Arch Linux，安装必要的包...${NC}"
        echo -e "${YELLOW}请运行以下命令安装依赖:${NC}"
        echo "sudo pacman -S mingw-w64-gcc mingw-w64-cmake mingw-w64-qt5-base mingw-w64-qt5-tools"
        
    elif command -v apt &> /dev/null; then
        echo -e "${BLUE}检测到Debian/Ubuntu系统，安装必要的包...${NC}"
        echo -e "${YELLOW}请运行以下命令安装依赖:${NC}"
        echo "sudo apt update"
        echo "sudo apt install gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 cmake"
        echo "sudo apt install mingw-w64-x86-64-qt5base-dev mingw-w64-x86-64-qt5tools"
        
    elif command -v yum &> /dev/null; then
        echo -e "${BLUE}检测到RHEL/CentOS系统，安装必要的包...${NC}"
        echo -e "${YELLOW}请运行以下命令安装依赖:${NC}"
        echo "sudo yum install mingw64-gcc mingw64-gcc-c++ mingw64-cmake"
        
    else
        echo -e "${YELLOW}未识别的Linux发行版，请手动安装以下依赖:${NC}"
        echo "- mingw-w64交叉编译工具链"
        echo "- CMake"
        echo "- Windows版本的Qt5开发库"
    fi
    
else
    echo -e "${RED}此脚本仅支持Linux系统${NC}"
    exit 1
fi

echo -e "${BLUE}检查Rust工具链...${NC}"

# 检查Rust
if ! command -v rustup &> /dev/null; then
    echo -e "${RED}错误: 未找到rustup${NC}"
    echo -e "${YELLOW}请访问 https://rustup.rs/ 安装Rust${NC}"
    exit 1
fi

# 安装Windows目标
if ! rustup target list --installed | grep -q "x86_64-pc-windows-gnu"; then
    echo -e "${YELLOW}安装Windows目标工具链...${NC}"
    rustup target add x86_64-pc-windows-gnu
    echo -e "${GREEN}✓ Windows目标工具链安装完成${NC}"
else
    echo -e "${GREEN}✓ Windows目标工具链已安装${NC}"
fi

# 检查交叉编译工具
echo -e "${BLUE}检查交叉编译工具...${NC}"

MISSING_TOOLS=()

if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    MISSING_TOOLS+=("x86_64-w64-mingw32-gcc")
fi

if ! command -v x86_64-w64-mingw32-g++ &> /dev/null; then
    MISSING_TOOLS+=("x86_64-w64-mingw32-g++")
fi

if ! command -v x86_64-w64-mingw32-ar &> /dev/null; then
    MISSING_TOOLS+=("x86_64-w64-mingw32-ar")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo -e "${RED}缺少以下工具: ${MISSING_TOOLS[*]}${NC}"
    echo -e "${YELLOW}请安装mingw-w64交叉编译工具链${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 交叉编译工具检查完成${NC}"

# 检查Qt
echo -e "${BLUE}检查Qt环境...${NC}"
if command -v qmake &> /dev/null; then
    echo -e "${GREEN}✓ 找到系统Qt${NC}"
    qmake --version
else
    echo -e "${YELLOW}警告: 未找到系统Qt，交叉编译可能需要额外配置${NC}"
fi

echo -e "${GREEN}🎉 环境检查完成！${NC}"
echo -e "${BLUE}现在可以运行: ./scripts/cross_compile_windows.sh${NC}"
