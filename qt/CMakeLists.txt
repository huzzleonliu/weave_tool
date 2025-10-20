cmake_minimum_required(VERSION 3.16)
project(picture_process_qt LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt5 5.15 COMPONENTS Core Gui Widgets Qml Quick QmlModels QuickControls2 REQUIRED)

# Rust static library (debug): the Rust target dir is one level up from qt/
set(GEN_RS_GEN ${CMAKE_CURRENT_SOURCE_DIR}/../src/gen/target/debug/libpicture_process_generated.a)
set(GEN_CPP ${CMAKE_CURRENT_SOURCE_DIR}/generated/viewer_cxx.cpp)

qt5_add_resources(QML_RCS qml.qrc)

add_executable(picture_process_qt
  main.cpp
  ${QML_RCS}
)

target_link_libraries(picture_process_qt
  Qt5::Core Qt5::Gui Qt5::Widgets Qt5::Qml Qt5::Quick Qt5::QmlModels Qt5::QuickControls2
  ${GEN_RS_GEN}
)

add_custom_target(build_gen_crate
  COMMAND cargo build
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../src/gen
  COMMENT "Building generated Rust crate"
)
add_dependencies(picture_process_qt build_gen_crate)

# Optionally include generated C++ if exists
if(EXISTS ${GEN_CPP})
  target_sources(picture_process_qt PRIVATE ${GEN_CPP})
  target_include_directories(picture_process_qt PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/generated)
endif()

# Helper target to run generator
add_custom_target(gen_bindings
  COMMAND rust_qt_binding_generator ${CMAKE_CURRENT_SOURCE_DIR}/../bindings.json
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/..
  BYPRODUCTS ${GEN_CPP}
  COMMENT "Generating Qt bindings via rust_qt_binding_generator"
)

# Run from repo root so QML can be loaded via data
set_target_properties(picture_process_qt PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)


