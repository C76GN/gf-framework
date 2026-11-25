//! 从当前 Rust 工具链及仓库汇总许可证，供发布的原生库内嵌。
use std::{env, fs, path::PathBuf, process::Command};

fn main() {
    // 移动端直接打包动态库，许可证随库内嵌才能覆盖仅导出部分资源的游戏。
    let rustc = env::var_os("RUSTC").expect("Cargo sets RUSTC");
    let output = Command::new(rustc)
        .args(["--print", "sysroot"])
        .output()
        .expect("query the Rust sysroot");
    assert!(output.status.success(), "rustc --print sysroot failed");
    let sysroot = String::from_utf8(output.stdout).expect("UTF-8 Rust sysroot");
    let standard = PathBuf::from(sysroot.trim()).join("share/doc/rust/COPYRIGHT-library.html");
    let mut notices = String::from("GF Framework\n\n");
    for name in ["../../LICENSE.md", "THIRD_PARTY_NOTICES.txt"] {
        println!("cargo:rerun-if-changed={name}");
        notices.push_str(
            &fs::read_to_string(name)
                .expect("read GF notices")
                .replace("\r\n", "\n"),
        );
        notices.push_str("\n\n");
    }
    println!("cargo:rerun-if-changed={}", standard.display());
    notices.push_str(&fs::read_to_string(standard).expect("read the pinned Rust library notices"));
    let out = PathBuf::from(env::var_os("OUT_DIR").expect("Cargo sets OUT_DIR"));
    fs::write(out.join("notices.txt"), notices).expect("write native notices");
}
