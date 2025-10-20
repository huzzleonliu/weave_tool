fn main() {
    println!("cargo:rerun-if-changed=bindings.json");
    // Try to run generator; if missing, emit a warning and continue (Qt side can still build)
    if let Ok(status) = std::process::Command::new("rust_qt_binding_generator").arg("bindings.json").status() {
        if !status.success() {
            println!("cargo:warning=rust_qt_binding_generator exited with non-zero status");
        }
    } else {
        println!("cargo:warning=rust_qt_binding_generator not found in PATH; skipping generation");
    }
}


