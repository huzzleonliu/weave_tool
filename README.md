# picture-process（Qt/QML + Rust，基于 rust-qt-binding-generator）

## 依赖
- Rust 工具链（cargo）
- Qt 5（Core/Gui/Qml/Quick/Widgets/QuickControls2）
- CMake 3.16+
- 生成器：`cargo install rust_qt_binding_generator`

## 结构
- `src/gen/`：生成器使用的 Rust 子 crate，导出 `ImageViewer` 的 C 接口
  - `viewer_interface.rs`：生成器产物的接口胶水（FFI/UTF16转换/信号发射）
  - `viewer_impl.rs`：业务实现（图像处理、阈值映射、清理散点、文件监听）。内部通过 `with_mut` 将不安全代码集中，便于理解与维护
  - `lib.rs`：模块导出
- `src/lib.rs`：保留的独立 C 接口示例（演示用途），主路径为上面的 `src/gen/`
- `qt/`：Qt/CMake 主程序，QML 在 `qt/qml/main.qml`
- `bindings.json`：生成配置，产物位于 `qt/generated/`

## 一键构建与运行
```bash
# 在仓库根目录
./scripts/build_and_run_linux.sh /绝对路径/图片.png  # Linux
./scripts/build_and_run_macos.sh /绝对路径/图片.png  # macOS
pwsh -File ./scripts/build_and_run_windows.ps1 C:\\path\\to\\image.png  # Windows
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
- 灰度预览：保留 alpha==0 的像素为透明，其余像素 alpha=255
- 阈值映射：支持“平均模式/分段模式”，按 stops 分段
- 清理散点：以 8 邻域统计改色（可扩展为阈值化+形态学）
- 监听 PNG 文件变更并自动刷新（60ms 节流）

## 架构与数据流
1. `qt/main.cpp` 创建 `ImageViewer`（生成的 C++ 类），注入 QML 上下文 `viewer`
2. QML 调用 `viewer.*` 方法，C++ 桥经由 `viewer_cxx.cpp` 进入 Rust 的 `viewer_interface.rs`
3. `viewer_interface.rs` 将调用转发到 `viewer_impl.rs` 的 `ImageViewer` 实现
4. Rust 侧通过 `ImageViewerEmitter` 向 QML 发出 `*_Changed` 信号，QML 根据属性更新 UI

## 开发者指南
- 新增图像处理功能：
  1) 在 `bindings.json` 的 `functions` 中添加接口
  2) 运行 `cmake --build qt/build -t gen_bindings` 以生成桥接代码
  3) 在 `viewer_impl.rs` 实现对应方法，并使用 `self.with_mut` 更新状态+发信号
- 线程与信号：I/O（如文件监听）建议放到线程；UI 刷新通过 `emit.*Changed()` 节流触发
- 临时文件：
  - 命名规则：`.gray.tmp.png` / `.threshold.tmp.png` / `.cleanup.tmp.png`
  - 由 `save_processed()` 覆盖回原图并清理，或通过 `cleanup_temp_files()` 清理由来

## 备注
- 若 FileDialog 报 Widgets 相关错误，请确认 `Qt5::Widgets` 已安装并链接。
- 若 CMake 报“源目录与缓存不一致”，请使用脚本（Linux/macOS/Windows）自动清理后重配。
