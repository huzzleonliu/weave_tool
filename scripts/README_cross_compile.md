# Windows交叉编译脚本说明

本目录包含用于从Linux系统交叉编译生成64位Windows可执行文件的脚本。

## 脚本文件

- `cross_compile_windows.sh` - 主要的交叉编译脚本
- `cross_compile_simple.sh` - 简化的交叉编译脚本（绕过CMake问题）
- `cross_compile_workaround.sh` - 实用的交叉编译解决方案（推荐）
- `setup_cross_compile_env.sh` - 环境设置和依赖检查脚本
- `fix_cmake_cross_compile.sh` - 修复CMake交叉编译问题的脚本
- `README_cross_compile.md` - 本说明文件

## 使用方法

### 1. 环境准备

首先运行环境设置脚本来检查和安装必要的依赖：

```bash
./scripts/setup_cross_compile_env.sh
```

### 2. 执行交叉编译

**推荐方案: 使用实用解决方案**
```bash
./scripts/cross_compile_workaround.sh
```

**完整方案: 使用主要脚本**
```bash
./scripts/cross_compile_windows.sh
```

### 3. 如果遇到CMake错误

如果遇到类似 "target pattern contains no '%'" 的CMake错误，可以尝试以下解决方案：

**方案1: 使用实用解决方案（推荐）**
```bash
./scripts/cross_compile_workaround.sh
```

**方案2: 使用简化脚本**
```bash
./scripts/cross_compile_simple.sh
```

**方案3: 使用修复脚本**
```bash
./scripts/fix_cmake_cross_compile.sh
```

## 依赖要求

### 必需依赖

1. **Rust工具链**
   - rustup
   - Windows目标: `x86_64-pc-windows-gnu`

2. **交叉编译工具链**
   - `x86_64-w64-mingw32-gcc`
   - `x86_64-w64-mingw32-g++`
   - `x86_64-w64-mingw32-ar`
   - `x86_64-w64-mingw32-windres`

3. **CMake**
   - 用于构建Qt部分

### 可选依赖

- **Windows版本Qt5** (推荐)
  - 提供更好的Qt交叉编译支持
  - 路径通常在 `/usr/x86_64-w64-mingw32/lib/qt5`

## 安装依赖

### Arch Linux

```bash
sudo pacman -S mingw-w64-gcc mingw-w64-cmake mingw-w64-qt5-base mingw-w64-qt5-tools
```

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 cmake
sudo apt install mingw-w64-x86-64-qt5base-dev mingw-w64-x86-64-qt5tools
```

### RHEL/CentOS

```bash
sudo yum install mingw64-gcc mingw64-gcc-c++ mingw64-cmake
```

## 输出文件

成功编译后，会在项目根目录生成 `picture_process_qt.exe` 文件。

## 故障排除

### 常见问题

1. **找不到交叉编译器**
   - 确保已安装mingw-w64工具链
   - 检查PATH环境变量

2. **Qt交叉编译失败**
   - 尝试安装Windows版本的Qt5
   - 检查CMAKE_PREFIX_PATH设置

3. **Rust交叉编译失败**
   - 确保已安装Windows目标: `rustup target add x86_64-pc-windows-gnu`
   - 检查.cargo/config.toml配置

4. **CMake构建错误: "target pattern contains no '%'"**
   - 这是交叉编译环境下的常见问题
   - 运行 `./scripts/fix_cmake_cross_compile.sh` 使用简化配置
   - 或者手动清理build目录后重试

5. **生成的exe文件无法运行**
   - 检查是否缺少DLL依赖
   - 使用 `x86_64-w64-mingw32-objdump -p picture_process_qt.exe | grep DLL` 查看依赖

### 调试信息

脚本会输出详细的构建信息，包括：
- 环境检查结果
- 构建步骤进度
- 错误信息和警告

如果遇到问题，请检查脚本输出的错误信息并参考上述故障排除指南。
