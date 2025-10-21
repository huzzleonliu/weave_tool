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
