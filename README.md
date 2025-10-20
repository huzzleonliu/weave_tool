# picture-process（Qt/QML + rust-qt-binding-generator）

## 依赖
- Rust 工具链（cargo）
- Qt 5（Core/Gui/Qml/Quick/Widgets/QuickControls2）
- CMake 3.16+
- 生成器：`cargo install rust_qt_binding_generator`

## 结构
- `src/gen/`：生成器使用的 Rust 子 crate，导出 `ImageViewer` 的 C 接口
- `qt/`：Qt/CMake 主程序，QML 在 `qt/qml/main.qml`
- `bindings.json`：生成配置，产物位于 `qt/generated/`

## 一键构建与运行
```bash
# 在仓库根目录
./scripts/build_and_run.sh /绝对路径/图片.png
```

等价步骤：
```bash
# 1) 生成 Rust 子 crate
cd src/gen && cargo build && cd -

# 2) Qt/CMake 构建
cd qt
cmake -S . -B build
cmake --build build -t gen_bindings
cmake --build build -j

# 3) 运行（可选参数：PNG 路径）
./build/picture_process_qt /path/to/image.png
```

## 功能
- 打开 PNG 并查看；鼠标滚轮缩放、状态提示
- 监听所选 PNG 文件变更并自动刷新（60ms 节流）

## 备注
- 若 FileDialog 报 Widgets 相关错误，请确认 `Qt5::Widgets` 已安装并链接。
