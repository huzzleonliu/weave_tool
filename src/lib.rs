use std::{path::PathBuf, sync::mpsc, thread, time::Duration};

use anyhow::Result;
use notify::{EventKind, RecommendedWatcher, RecursiveMode, Watcher};

static mut WATCHER_LEAK: Option<*mut RecommendedWatcher> = None;

#[no_mangle]
pub extern "C" fn pp_start_watcher(path_ptr: *const libc::c_char) -> bool {
    let cstr = unsafe { std::ffi::CStr::from_ptr(path_ptr) };
    let path_str = match cstr.to_str() { Ok(s) => s.to_string(), Err(_) => return false };
    let path = PathBuf::from(path_str);
    if let Ok(w) = start_watcher_bridge(path) {
        unsafe {
            let boxed = Box::new(w);
            WATCHER_LEAK = Some(Box::into_raw(boxed));
        }
        true
    } else {
        false
    }
}

fn start_watcher_bridge(image_path: PathBuf) -> Result<RecommendedWatcher> {
    let (tx, rx) = mpsc::channel();

    let mut watcher = notify::recommended_watcher(move |res| {
        let _ = tx.send(res);
    })?;

    watcher.watch(&image_path, RecursiveMode::NonRecursive)?;

    thread::spawn(move || {
        let mut last_emit = std::time::Instant::now();
        while let Ok(res) = rx.recv() {
            match res {
                Ok(event) => match event.kind {
                    EventKind::Modify(_) | EventKind::Create(_) => {
                        if last_emit.elapsed() >= Duration::from_millis(60) {
                            unsafe { pp_on_file_bumped(); }
                            last_emit = std::time::Instant::now();
                        }
                    }
                    _ => {}
                },
                Err(_) => break,
            }
        }
    });

    Ok(watcher)
}

#[allow(improper_ctypes)]
extern "C" { fn pp_on_file_bumped(); }


