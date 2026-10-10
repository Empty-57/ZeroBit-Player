#[cfg(target_os = "windows")]
use std::os::windows::raw::HANDLE;

#[cfg(target_os = "windows")]
#[link(name = "kernel32")]
extern "system" {
    fn GetCurrentProcess() -> HANDLE;
    fn SetProcessWorkingSetSize(
        hProcess: HANDLE,
        dwMinimumWorkingSetSize: usize,
        dwMaximumWorkingSetSize: usize,
    ) -> i32;
}

#[flutter_rust_bridge::frb]
pub fn trim_memory() -> bool {
    #[cfg(target_os = "windows")]
    unsafe {
        let process = GetCurrentProcess();
        // 如果 dwMinimumWorkingSetSize 和 dwMaximumWorkingSetSize 的值为 (SIZE_T) –1，则函数将从指定进程的工作集中删除尽可能多的页。
        SetProcessWorkingSetSize(process, usize::MAX, usize::MAX) != 0
    }
}
