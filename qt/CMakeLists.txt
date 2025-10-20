cmake_minimum_required(VERSION 3.16)
# 工程: Qt 前端，链接 Rust 生成的静态库
project(picture_process_qt LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# 依赖 Qt5 组件：Core/Gui/Widgets/Qml/Quick/QmlModels/QuickControls2
# 如遇到找不到模块，请确认 CMAKE_PREFIX_PATH 指向 Qt5 cmake 目录
find_package(Qt5 5.15 COMPONENTS Core Gui Widgets Qml Quick QmlModels QuickControls2 REQUIRED)

# Rust 静态库（Debug），路径相对于本目录的上级
# 如果需要 Release，请将 cargo build 改为 --release 并调整路径
set(GEN_RS_GEN ${CMAKE_CURRENT_SOURCE_DIR}/../src/gen/target/debug/libpicture_process_generated.a)
set(GEN_CPP ${CMAKE_CURRENT_SOURCE_DIR}/generated/viewer_cxx.cpp)

qt5_add_resources(QML_RCS qml.qrc)

# 可执行文件（包含 QML 资源）
add_executable(picture_process_qt
  main.cpp
  ${QML_RCS}
)

# 关联 Qt 库与 Rust 静态库
target_link_libraries(picture_process_qt
  Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Qml Qt5::Quick Qt5::QmlModels Qt5::QuickControls2
  ${GEN_RS_GEN}
)

# 构建 Rust 子 crate（生成静态库）
add_custom_target(build_gen_crate
  COMMAND cargo build
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../src/gen
  COMMENT "Building generated Rust crate"
)
add_dependencies(picture_process_qt build_gen_crate)

# 可选：若生成的 C++ 头/源已存在，则并入编译并添加包含路径
if(EXISTS ${GEN_CPP})
  target_sources(picture_process_qt PRIVATE ${GEN_CPP})
  target_include_directories(picture_process_qt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/generated)
endif()

# 绑定生成器：根据 bindings.json 生成 C++/Rust 桥接代码
add_custom_target(gen_bindings
  COMMAND rust_qt_binding_generator ${CMAKE_CURRENT_SOURCE_DIR}/../bindings.json
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
  BYPRODUCTS ${GEN_CPP}
  COMMENT "Generating Qt bindings via rust_qt_binding_generator"
)

# 输出目录：放在 CMake 的 build 根目录，便于运行时加载资源
set_target_properties(picture_process_qt PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)


