use core::ffi::{c_float, c_int, c_uint, c_void};

#[repr(C)]
#[derive(Default)]
pub struct BASS_WASAPI_INFO {
    pub initflags: u32,
    pub freq: u32,
    pub chans: u32,
    pub format: u32,
    pub buflen: u32,
    pub volmax: f32,
    pub volmin: f32,
    pub volstep: f32,
}

pub(crate) type BASS_WASAPI_GetInfo = unsafe extern "C" fn(info: *mut BASS_WASAPI_INFO) -> c_int;

pub(crate) type WASAPIPROC =
    Option<unsafe extern "C" fn(buffer: *mut c_void, length: c_uint, user: *mut c_void) -> c_uint>;

pub(crate) extern "C" fn dummy_wasapi_proc(
    _buffer: *mut c_void,
    _length: c_uint,
    _user: *mut c_void,
) -> c_uint {
    // 不做任何处理，返回 0 表示“没有写入数据”
    0
}

pub(crate) type BASS_WASAPI_Init = unsafe extern "C" fn(
    device: c_int,     // -1 = 默认设备
    freq: c_uint,      //输出采样率(hz): 0 与设备一致，或者指定采样率
    chans: c_uint,     //声道
    flags: c_uint,     //初始化选项标志 独占: BASS_WASAPI_EXCLUSIVE | BASS_WASAPI_AUTOFORMAT
    buffer: c_float,   // 缓冲区秒数
    period: c_float,   // 设备周期（0 = 默认）
    proc: WASAPIPROC,  // 回调指针，或 NULL
    user: *mut c_void, // 回调用户参数
) -> c_int;

pub(crate) type BASS_WASAPI_Start = unsafe extern "C" fn() -> c_int;

pub(crate) type BASS_WASAPI_Free = unsafe extern "C" fn() -> c_int;
