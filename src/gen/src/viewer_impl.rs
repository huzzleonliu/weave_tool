#![allow(unused_imports)]
#![allow(unused_variables)]
#![allow(dead_code)]

// 设计说明（重要）：
// 本文件实现 QML/C++ 侧暴露的 ImageViewer 逻辑。
// 由于生成的 trait 方法多为 &self，但需要在只读方法中变更内部状态（如更新路径、触发信号），
// 本实现使用 UnsafeCell 提供“内部可变性”，避免 & -> &mut 的未定义行为。
use crate::viewer_interface::*;
use notify::Watcher;
use serde::{Deserialize, Serialize};
use std::cell::{RefCell, UnsafeCell};

#[derive(Deserialize)]
struct ThresholdMappingData {
    stops: Vec<u8>,
    #[serde(rename = "averageMode")]
    average_mode: bool,
}

pub struct ImageViewer {
    // 生成器提供的发射器，用于向 QML 侧发送属性变更信号（内部可变以便在 &self 中使用）
    emit: UnsafeCell<ImageViewerEmitter>,
    // 以下字段需要在 &self 方法中被修改，使用 UnsafeCell 提供内部可变性
    image_path: UnsafeCell<String>,
    display_path: UnsafeCell<String>,
    pending_path: UnsafeCell<Option<String>>,
    // watcher 放在 RefCell 中，避免与字符串借用相互影响
    watcher: RefCell<Option<notify::RecommendedWatcher>>,
}


impl ImageViewerTrait for ImageViewer {
    fn new(emit: ImageViewerEmitter) -> ImageViewer {
        ImageViewer {
            emit: UnsafeCell::new(emit),
            image_path: UnsafeCell::new(String::new()),
            display_path: UnsafeCell::new(String::new()),
            pending_path: UnsafeCell::new(None),
            watcher: RefCell::new(None),
        }
    }
    fn emit(&mut self) -> &mut ImageViewerEmitter {
        unsafe { &mut *self.emit.get() }
    }
    fn image_path(&self) -> &str {
        unsafe { &*self.image_path.get() }
    }
    fn display_path(&self) -> &str {
        let disp = unsafe { &*self.display_path.get() };
        if !disp.is_empty() { disp } else { unsafe { &*self.image_path.get() } }
    }
    fn has_pending(&self) -> bool { unsafe { (*self.pending_path.get()).is_some() } }
    fn set_image_path(&self, path: String) -> () {
        // 设置原图路径，通知 QML 更新
        unsafe { *self.image_path.get() = path; }
        unsafe { (&mut *self.emit.get()).image_path_changed(); }
    }
    fn gray_preview(&self) -> () {
        let path = unsafe { (*self.image_path.get()).clone() };
        if path.is_empty() { return; }
        // 读取并转换为 RGBA8，保留 alpha；将 RGB 设置为相同亮度值
        let img = match image::open(&path) { Ok(i) => i, Err(_) => return };
        let mut rgba: image::RgbaImage = img.to_rgba8();
        for p in rgba.pixels_mut() {
            let r = p[0] as u32;
            let g = p[1] as u32;
            let b = p[2] as u32;
            let a = p[3];
            
            // ITU-R BT.601 近似加权，整数计算避免浮点
            let luma = ((299 * r + 587 * g + 114 * b) / 1000) as u8;
            
            // 新的alpha处理逻辑：
            // - alpha为0的像素设为(0,0,0,0)
            // - alpha不为0的像素alpha设为255
            if a == 0 {
                p[0] = 0;
                p[1] = 0;
                p[2] = 0;
                p[3] = 0;
            } else {
                p[0] = luma;
                p[1] = luma;
                p[2] = luma;
                p[3] = 255;
            }
        }
        let dyn_img = image::DynamicImage::ImageRgba8(rgba);
        // 写入临时文件，不覆盖原图
        let tmp_path = format!("{}{}", &path, ".gray.tmp.png");
        let _ = dyn_img.save(&tmp_path);
        // 标记待保存并刷新显示
        unsafe {
            *self.pending_path.get() = Some(tmp_path);
            *self.display_path.get() = (*self.pending_path.get()).clone().unwrap_or_default();
            (&mut *self.emit.get()).display_path_changed();
            (&mut *self.emit.get()).has_pending_changed();
        }
    }
    fn save_processed(&self) -> () {
        // 覆盖原图并清理临时文件；触发多路信号
        // 注意：先复制/删除，再一次性更新状态，避免部分更新导致的 UI 闪烁
        let (img_path, tmp_opt) = unsafe { ((*self.image_path.get()).clone(), (*self.pending_path.get()).clone()) };
        if let Some(tmp) = tmp_opt {
            let _ = std::fs::copy(&tmp, &img_path);
            let _ = std::fs::remove_file(&tmp);
            unsafe {
                *self.pending_path.get() = None;
                (*self.display_path.get()).clear();
                (&mut *self.emit.get()).image_path_changed();
                (&mut *self.emit.get()).display_path_changed();
                (&mut *self.emit.get()).has_pending_changed();
            }
        }
    }
    fn refresh_display(&self) -> () {
        // 用原图内容覆盖当前临时显示文件（若存在），保持显示路径不变
        let (img_path, disp_opt) = unsafe {
            let img = (*self.image_path.get()).clone();
            let disp = (*self.display_path.get()).clone();
            if disp.is_empty() { (img, None) } else { (img, Some(disp)) }
        };
        if let Some(disp) = disp_opt { let _ = std::fs::copy(&img_path, &disp); }
        unsafe {
            (&mut *self.emit.get()).display_path_changed();
            (&mut *self.emit.get()).image_path_changed();
        }
    }
    fn apply_threshold_mapping(&self, thresholds_json: String) -> () {
        // 解析阈值映射数据JSON
        let mapping_data: ThresholdMappingData = match serde_json::from_str(&thresholds_json) {
            Ok(data) => data,
            Err(e) => {
                eprintln!("Error parsing threshold mapping JSON: {}", e);
                return;
            }
        };
        
        let thresholds = mapping_data.stops;
        let is_average_mode = mapping_data.average_mode;
        
        if thresholds.is_empty() {
            eprintln!("No thresholds provided");
            return;
        }
        
        // 总是使用原图作为源文件
        let original_path = unsafe { &*self.image_path.get() };
            
            if original_path.is_empty() {
                eprintln!("No original image loaded for threshold mapping");
                return;
            }
            
            // 从原图加载图片
            let img = match image::open(original_path) {
                Ok(i) => i.to_rgba8(),
                Err(e) => {
                    eprintln!("Error loading original image for threshold mapping: {}", e);
                    return;
                }
            };
            
            let (width, height) = img.dimensions();
            let mut mapped_img = image::RgbaImage::new(width, height);
            
            // 应用阈值映射和alpha修改逻辑
            for y in 0..height {
                for x in 0..width {
                    let pixel = img.get_pixel(x, y);
                    let (r, g, b, a) = (pixel[0], pixel[1], pixel[2], pixel[3]);
                    
                    // 计算灰度值
                    let gray = ((299 * r as u32 + 587 * g as u32 + 114 * b as u32) / 1000) as u8;
                    
                    // 应用alpha修改逻辑和阈值映射
                    let (mapped_gray, mapped_alpha) = if a == 0 {
                        (0, 0) // 透明像素保持为(0,0,0,0)
                    } else {
                        let segment_gray = if is_average_mode {
                            // 平均模式：计算该段的平均灰度值
                            let mut result = 0;
                            for (i, &threshold) in thresholds.iter().enumerate() {
                                if gray <= threshold {
                                    let prev_threshold = if i == 0 { 0 } else { thresholds[i-1] };
                                    result = ((prev_threshold as u16 + threshold as u16) / 2) as u8;
                                    break;
                                }
                            }
                            // 如果灰度值大于所有阈值，使用最后一段
                            if gray > *thresholds.last().unwrap() {
                                let last_threshold = *thresholds.last().unwrap();
                                result = ((last_threshold as u16 + 255) / 2) as u8;
                            }
                            result
                        } else {
                            // 分段模式：均匀分布，最亮段为255，最暗段为0
                            let segment_count = thresholds.len() + 1; // 段数 = 阈值数 + 1
                            let mut segment_index = 0;
                            
                            for (i, &threshold) in thresholds.iter().enumerate() {
                                if gray <= threshold {
                                    segment_index = i;
                                    break;
                                }
                                segment_index = i + 1;
                            }
                            
                            if segment_count == 1 {
                                128 // 只有一段时使用中值
                            } else if segment_index == 0 {
                                0 // 最暗段映射为纯黑色
                            } else if segment_index == segment_count - 1 {
                                255 // 最亮段映射为纯白色
                            } else {
                                // 中间段均匀分布
                                ((255 * segment_index) / (segment_count - 1)) as u8
                            }
                        };
                        (segment_gray, 255) // alpha修改：alpha不为0的像素alpha设为255
                    };
                    
                    mapped_img.put_pixel(x, y, image::Rgba([mapped_gray, mapped_gray, mapped_gray, mapped_alpha]));
                }
            }
            
            // 保存映射后的图片到临时文件
            let temp_path = format!("{}{}", original_path, ".threshold.tmp.png");
            let dyn_img = image::DynamicImage::ImageRgba8(mapped_img);
            if let Err(e) = dyn_img.save(&temp_path) {
                eprintln!("Error saving threshold mapped image: {}", e);
                return;
            }
            
            // 更新显示路径和待保存状态
            unsafe {
                *self.display_path.get() = temp_path.clone();
                *self.pending_path.get() = Some(temp_path);
                (&mut *self.emit.get()).display_path_changed();
                (&mut *self.emit.get()).has_pending_changed();
            }
    }
    fn cleanup_scattered_pixels(&self) -> () {
        let original_path = unsafe { &*self.image_path.get() };
            
            if original_path.is_empty() {
                eprintln!("No original image loaded for cleanup");
                return;
            }
            
            // 从原图加载图片
            let img = match image::open(original_path) {
                Ok(i) => i.to_rgba8(),
                Err(e) => {
                    eprintln!("Error loading original image for cleanup: {}", e);
                    return;
                }
            };
            
            let (width, height) = img.dimensions();
            let mut cleaned_img = img.clone();
            
            // 从左上角开始遍历所有非透明像素
            for y in 0..height {
                for x in 0..width {
                    let pixel = img.get_pixel(x, y);
                    let (r, g, b, a) = (pixel[0], pixel[1], pixel[2], pixel[3]);
                    
                    // 跳过透明像素
                    if a == 0 {
                        continue;
                    }
                    
                    // 检查周围8个像素的颜色
                    let mut neighbor_colors = std::collections::HashMap::new();
                    let mut neighbor_count = 0;
                    
                    for dy in -1..=1 {
                        for dx in -1..=1 {
                            if dx == 0 && dy == 0 {
                                continue; // 跳过中心像素
                            }
                            
                            let nx = x as i32 + dx;
                            let ny = y as i32 + dy;
                            
                            // 边界检查
                            if nx < 0 || nx >= width as i32 || ny < 0 || ny >= height as i32 {
                                continue;
                            }
                            
                            let neighbor_pixel = img.get_pixel(nx as u32, ny as u32);
                            let (nr, ng, nb, na) = (neighbor_pixel[0], neighbor_pixel[1], neighbor_pixel[2], neighbor_pixel[3]);
                            
                            // 只考虑非透明像素
                            if na > 0 {
                                let color_key = (nr, ng, nb);
                                *neighbor_colors.entry(color_key).or_insert(0) += 1;
                                neighbor_count += 1;
                            }
                        }
                    }
                    
                    // 如果周围有非透明像素且颜色不同，则进行清理
                    if neighbor_count > 0 && !neighbor_colors.contains_key(&(r, g, b)) {
                        // 找到数量最多的颜色
                        let mut max_count = 0;
                        let mut most_common_colors = Vec::new();
                        
                        for (&color, &count) in &neighbor_colors {
                            if count > max_count {
                                max_count = count;
                                most_common_colors.clear();
                                most_common_colors.push(color);
                            } else if count == max_count {
                                most_common_colors.push(color);
                            }
                        }
                        
                        // 如果有多个颜色数量相同，选择较深的颜色
                        if most_common_colors.len() > 1 {
                            let mut darkest_color = most_common_colors[0];
                            let mut darkest_brightness = (darkest_color.0 as u32 + darkest_color.1 as u32 + darkest_color.2 as u32) / 3;
                            
                            for &color in &most_common_colors[1..] {
                                let brightness = (color.0 as u32 + color.1 as u32 + color.2 as u32) / 3;
                                if brightness < darkest_brightness {
                                    darkest_color = color;
                                    darkest_brightness = brightness;
                                }
                            }
                            
                            cleaned_img.put_pixel(x, y, image::Rgba([darkest_color.0, darkest_color.1, darkest_color.2, a]));
                        } else if let Some(&new_color) = most_common_colors.first() {
                            cleaned_img.put_pixel(x, y, image::Rgba([new_color.0, new_color.1, new_color.2, a]));
                        }
                    }
                }
            }
            
            // 保存清理后的图片到临时文件
            let temp_path = format!("{}{}", original_path, ".cleanup.tmp.png");
            let dyn_img = image::DynamicImage::ImageRgba8(cleaned_img);
            if let Err(e) = dyn_img.save(&temp_path) {
                eprintln!("Error saving cleaned image: {}", e);
                return;
            }
            
            // 更新显示路径和待保存状态
            unsafe {
                *self.display_path.get() = temp_path.clone();
                *self.pending_path.get() = Some(temp_path);
                (&mut *self.emit.get()).display_path_changed();
                (&mut *self.emit.get()).has_pending_changed();
            }
    }
    fn cleanup_temp_files(&self) -> () {
        // 清理当前登记的临时文件
        let pending_snapshot = unsafe { (*self.pending_path.get()).clone() };
        if let Some(temp_path) = pending_snapshot {
            let _ = std::fs::remove_file(&temp_path);
            println!("Cleaned up temporary file: {}", temp_path);
        }
        // 扫描并清理同名基底的其他临时变体
        let image_path_snapshot = unsafe { (*self.image_path.get()).clone() };
        if !image_path_snapshot.is_empty() {
            let base_path = std::path::Path::new(&image_path_snapshot);
            if let Some(parent) = base_path.parent() {
                if let Some(file_stem) = base_path.file_stem() {
                    let temp_patterns = [
                        format!("{}.gray.tmp.png", file_stem.to_string_lossy()),
                        format!("{}.threshold.tmp.png", file_stem.to_string_lossy()),
                        format!("{}.cleanup.tmp.png", file_stem.to_string_lossy()),
                    ];
                    for pattern in &temp_patterns {
                        let temp_path = parent.join(pattern);
                        if temp_path.exists() { let _ = std::fs::remove_file(&temp_path); }
                    }
                }
            }
        }
    }
    fn start_watcher(&self, path: String) -> () {
        // 启动文件监听，用于感知目标 PNG 文件变化，节流 60ms
        let (tx, rx) = std::sync::mpsc::channel();
        let result = notify::recommended_watcher(move |res| { let _ = tx.send(res); });
        if let Ok(mut w) = result {
            use notify::{RecursiveMode, EventKind};
            let _ = w.watch(std::path::Path::new(&path), RecursiveMode::NonRecursive);
            // 记录 watcher 并克隆一个发射器用于子线程触发 UI 刷新
            *self.watcher.borrow_mut() = Some(w);
            let mut emit_clone = unsafe { (&mut *self.emit.get()).clone() };
            std::thread::spawn(move || {
                let mut last = std::time::Instant::now();
                while let Ok(res) = rx.recv() {
                    if let Ok(event) = res {
                        match event.kind {
                            EventKind::Modify(_) | EventKind::Create(_) => {
                                if last.elapsed() >= std::time::Duration::from_millis(60) {
                                    emit_clone.image_path_changed();
                                    last = std::time::Instant::now();
                                }
                            }
                            _ => {}
                        }
                    } else { break; }
                }
            });
        }
    }
}

// 注意：所有内部写入均通过 UnsafeCell::get 获得可变指针后在局部 unsafe 作用域内完成。
