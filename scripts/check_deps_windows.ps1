#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 概要: Windows 下构建依赖检查
# 需求:
# - Rust 工具链: cargo, rustc
# - rust_qt_binding_generator (可选)
# - CMake >= 3.16
# - Qt5 (含 Core/Gui/Widgets/Qml/Quick/QmlModels/QuickControls2)
# - C/C++ 编译器: MSVC (建议) 或 MinGW；需与 Qt 工具链匹配

function Pass($msg){ Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Fail($msg){ Write-Host "[FAIL] $msg" -ForegroundColor Red }

function Has-Cmd($name){
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  if($null -ne $cmd){ Pass "$name: $($cmd.Path)"; return $true } else { Fail "$name 未找到"; return $false }
}

$ok = $true

Write-Host "== 检查 Rust 工具链 =="
if(-not (Has-Cmd cargo)){ $ok = $false }
if(-not (Has-Cmd rustc)){ $ok = $false }

Write-Host "== 检查 rust_qt_binding_generator (可选) =="
if(-not (Has-Cmd rust_qt_binding_generator)){
  Warn "未检测到 rust_qt_binding_generator。可执行: cargo install rust_qt_binding_generator"
}

Write-Host "== 检查 CMake (>=3.16) =="
if(Has-Cmd cmake){
  $verLine = (cmake --version | Select-Object -First 1)
  if($verLine -match "([0-9]+)\.([0-9]+)\."){
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]
    if($major -lt 3 -or ($major -eq 3 -and $minor -lt 16)){
      Warn "CMake 版本过低: $verLine"
    }
  }
} else { $ok = $false }

Write-Host "== 检查编译器 (MSVC cl 或 MinGW g++) =="
$hasCl = Has-Cmd cl
$hasGpp = Has-Cmd g++
if(-not ($hasCl -or $hasGpp)){
  Warn "未检测到 cl 或 g++。请安装 Visual Studio C++ 组件或 MinGW，并确保与 Qt 构建匹配"
}

Write-Host "== 检查 Qt5 =="
$qtDir = $env:Qt5_DIR
if([string]::IsNullOrEmpty($qtDir)){
  Warn "未设置环境变量 Qt5_DIR。建议设置到 Qt5 的 cmake 目录，如 C:\Qt\5.15.2\msvc2019_64\lib\cmake\Qt5"
} else {
  Pass "Qt5_DIR=$qtDir"
}

Write-Host ""
if($ok){ Write-Host "依赖检查完成（如有 WARN 请按提示处理）" -ForegroundColor Green; exit 0 }
else { Write-Host "依赖检查存在问题，请根据上方提示安装缺失组件" -ForegroundColor Yellow; exit 1 }

#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

function Ok($msg){ Write-Host "[OK] $msg" -ForegroundColor Green }
function Warn($msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Fail($msg){ Write-Host "[ERR] $msg" -ForegroundColor Red; exit 1 }

function Test-Cmd($cmd, $hint){
	$found = (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null
	if($found){ Ok "$cmd 已安装"; return $true }
	else { Warn "$cmd 未找到"; if($hint){ Write-Host "  安装提示: $hint" }; return $false }
}

$missing = $false

# Rust (winget or rustup-init.exe)
if(-not (Test-Cmd "cargo" "安装: winget install Rustlang.Rustup 或从 https://rustup.rs 下载 rustup-init.exe")){ $missing = $true }
if(-not (Test-Cmd "rustc" $null)){ $missing = $true }

# CMake
if(-not (Test-Cmd "cmake" "安装: winget install Kitware.CMake")){ $missing = $true }

# Qt5 (MSVC 工具链 + Qt 5.x)
# 检查 qmake.exe 是否在 PATH
if((Get-Command qmake.exe -ErrorAction SilentlyContinue)){
	Ok "qmake 可用"
}else{
	Warn "未检测到 qmake。请安装 Qt5 (含 Core/Gui/Widgets/Qml/Quick/QuickControls2) 并将 qmake.exe 加入 PATH"
	$missing = $true
}

# CMake 查找 Qt5
try {
	$code = @'
message(STATUS "Probing Qt5...")
find_package(Qt5 5.12 COMPONENTS Core Gui Widgets Qml Quick QmlModels QuickControls2 REQUIRED)
message(STATUS "Qt5 FOUND")
'@
	$null = cmake -P - <<< $code
	Ok "CMake 可找到 Qt5"
} catch {
	Warn "CMake 未能找到 Qt5。请设置 CMAKE_PREFIX_PATH 指向 Qt 安装目录 (含 lib/cmake/Qt5)"
	$missing = $true
}

# rust_qt_binding_generator
if((Get-Command rust_qt_binding_generator -ErrorAction SilentlyContinue)){
	Ok "rust_qt_binding_generator 已安装"
}else{
	Warn "rust_qt_binding_generator 未安装：运行 cargo install rust_qt_binding_generator"
}

if(-not $missing){ Write-Host "依赖检查通过。"; exit 0 }
else { Fail "依赖检查未通过，请根据上方提示安装缺失组件。" }
