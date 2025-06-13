use core::ffi::{c_char, c_double, c_float, c_int, c_uint, c_ulong, c_void};
use std::ffi::c_ulonglong;

pub(crate) type BASS_Init = unsafe extern "C" fn(
    device: c_int,       //要打开的音频设备编号，-1 表示使用系统默认设备
    freq: c_uint,        //输出采样率(hz)
    flags: c_uint,       //初始化选项标志，可按位或组合，0默认
    win: *mut c_void,    //窗口句柄（HWND）
    dsguid: *mut c_void, //DirectSound 设备的 GUID 指针。通常传 NULL 使用默认设备；
) -> c_int;

pub(crate) type BASS_Start = unsafe extern "C" fn() -> c_int;

pub(crate) type BASS_ChannelIsActive = unsafe extern "C" fn(handle: c_uint) -> c_uint;

pub(crate) type BASS_StreamCreateFile = unsafe extern "C" fn(
    mem: c_int, //0：file 指向的是一个以 \0 结尾的文件路径字符串（ANSI/UTF-8，或加 BASS_UNICODE 时用 UTF-16）。非 0：file 指向的是内存中的数据缓冲区，此时 length 必须指定缓冲区大小，BASS 就会当作内存流来读取。
    file: *const c_void, //当 mem==0 时，它是一个 C 字符串指针，指向要打开的音频文件路径（char* 或 wchar_t*）当 mem!=0 时，它是一个指向内存数据首地址的指针（BYTE*），BASS 会从这段内存创建流。
    offset: c_ulong,     //从文件或内存开头跳过的字节数，默认0
    length: c_ulong,     //要包含在流中的字节长度。
    flags: c_uint,       //创建流时的选项
) -> c_uint;

pub(crate) type BASS_ChannelGetAttribute = unsafe extern "C" fn(
    handle: c_uint,      // 通道句柄（HSTREAM、HMUSIC 等）
    attrib: c_uint,      // 属性标志，如 BASS_ATTRIB_VOL
    value: *mut c_float, // 值：0.0 — 1.0 之间
) -> c_int;

pub(crate) type BASS_ChannelSetAttribute =
    unsafe extern "C" fn(handle: c_uint, attrib: c_uint, value: c_float) -> c_int;

pub(crate) type BASS_ChannelPlay = unsafe extern "C" fn(handle: c_uint, restart: c_int) -> c_int;
pub(crate) type BASS_ChannelPause = unsafe extern "C" fn(handle: c_uint) -> c_int;
pub(crate) type BASS_ChannelStop = unsafe extern "C" fn(handle: c_uint) -> c_int;
pub(crate) type BASS_StreamFree = unsafe extern "C" fn(handle: c_uint) -> c_int;
pub(crate) type BASS_Free = unsafe extern "C" fn() -> c_int;
pub(crate) type BASS_ErrorGetCode = unsafe extern "C" fn() -> c_int;

pub(crate) type BASS_ChannelGetPosition =
    unsafe extern "C" fn(handle: c_uint, mode: c_uint) -> c_ulonglong;

pub(crate) type BASS_ChannelSetPosition =
    unsafe extern "C" fn(handle: c_uint, pos: c_ulonglong, mode: c_uint) -> c_int;

pub(crate) type BASS_ChannelBytes2Seconds =
    unsafe extern "C" fn(handle: c_uint, pos: c_ulonglong) -> c_double;

pub(crate) type BASS_ChannelSeconds2Bytes =
    unsafe extern "C" fn(handle: c_uint, pos: c_double) -> c_ulonglong;

pub type BASS_PluginLoad = unsafe extern "C" fn(
    file: *const c_char, // const char *
    flags: c_uint,       // DWORD
) -> c_uint;
