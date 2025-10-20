#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 用法: ./scripts/build_and_run_windows.ps1 [C:\绝对路径\图片.png]

function Invoke-Safe($ScriptBlock){
  try { & $ScriptBlock } catch { Write-Host $_ -ForegroundColor Red; exit 1 }
}

$ROOT_DIR = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$IMG = $args[0]

Write-Host "[0/3] 可选依赖检查 (失败不终止)"
try { & (Join-Path $ROOT_DIR 'scripts/check_deps_windows.ps1') } catch { Write-Host "依赖检查有警告，尝试继续构建..." -ForegroundColor Yellow }

Write-Host "[1/3] 构建 Rust 生成子 crate"
Push-Location (Join-Path $ROOT_DIR 'src/gen')
Invoke-Safe { cargo build }
Pop-Location

Write-Host "[2/3] 配置并构建 Qt/CMake 工程"
Push-Location (Join-Path $ROOT_DIR 'qt')

# 若缓存来自不同源路径，清理 build 目录以避免 CMake 源不匹配错误
if(Test-Path 'build/CMakeCache.txt'){
  $cache = Get-Content 'build/CMakeCache.txt' -ErrorAction SilentlyContinue | Where-Object { $_ -like 'CMAKE_HOME_DIRECTORY*' } | Select-Object -First 1
  if($cache -match '='){ $cachedSrc = $cache.Split('=')[-1] }
  $here = (Get-Location).Path
  if($cachedSrc -and ($cachedSrc -ne $here)){
    Write-Host "检测到旧的 CMake 缓存来自: $cachedSrc，与当前源目录不一致，清理 qt/build..."
    Remove-Item -Recurse -Force 'build'
  }
}

# 使用 NMake 或 Ninja，请根据环境调整生成器。默认尝试 cmake 自动检测。
Invoke-Safe { cmake -S . -B build }
try { cmake --build build -t gen_bindings } catch { Write-Host "生成绑定失败或跳过，若已存在生成文件可忽略" -ForegroundColor Yellow }
Invoke-Safe { cmake --build build --config Debug }

Write-Host "[3/3] 运行应用"
$exe = Join-Path (Join-Path (Get-Item 'build').FullName) 'picture_process_qt.exe'
if(Test-Path $exe){
  if($IMG){ & $exe $IMG } else { & $exe }
} else {
  # 某些生成器会将可执行文件放在子目录，如 build/Debug/
  $alt = Join-Path (Join-Path (Get-Item 'build').FullName) 'Debug/picture_process_qt.exe'
  if(Test-Path $alt){ if($IMG){ & $alt $IMG } else { & $alt } }
  else { Write-Host "未找到输出可执行文件" -ForegroundColor Red; exit 1 }
}

Pop-Location

#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"

$ROOT_DIR = (Resolve-Path "$PSScriptRoot/..\").Path
param(
	[string]$ImagePath
)

# 依赖快速检查（非强制）
$check = Join-Path $ROOT_DIR "scripts/check_deps_windows.ps1"
if(Test-Path $check){ try { & $check } catch { Write-Host "[WARN] 依赖检查失败，尝试继续构建" -ForegroundColor Yellow } }

Write-Host "[1/3] 构建生成 Rust 子 crate"
Push-Location (Join-Path $ROOT_DIR "src/gen")
cargo build
Pop-Location

Write-Host "[2/3] CMake 配置与生成"
Push-Location (Join-Path $ROOT_DIR "qt")
# 若缓存来自不同源路径，清理 build 目录以避免 CMake 源不匹配错误
if(Test-Path 'build/CMakeCache.txt'){
  $cache = Get-Content 'build/CMakeCache.txt' -ErrorAction SilentlyContinue | Where-Object { $_ -like 'CMAKE_HOME_DIRECTORY*' } | Select-Object -First 1
  if($cache -match '='){ $cachedSrc = $cache.Split('=')[-1] }
  $here = (Get-Location).Path
  if($cachedSrc -and ($cachedSrc -ne $here)){
    Write-Host "检测到旧的 CMake 缓存来自: $cachedSrc，与当前源目录不一致，清理 qt/build..."
    Remove-Item -Recurse -Force 'build'
  }
}

# 使用默认 VS 生成器；也可指定 -G "Visual Studio 17 2022"
cmake -S . -B build
cmake --build build --target gen_bindings || Write-Host "[WARN] 绑定生成失败或跳过" -ForegroundColor Yellow
cmake --build build --config Debug

Write-Host "[3/3] 运行应用"
$exe = Join-Path (Join-Path (Get-Item "build").FullName) "picture_process_qt.exe"
if(Test-Path $exe){
	if($ImagePath){ & $exe $ImagePath }
	else { & $exe }
}else{
	Write-Host "未找到可执行文件: $exe" -ForegroundColor Red
	exit 1
}

Pop-Location
