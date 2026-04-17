use crate::api::bass::bass_errs::{
    get_err_info, BASS_ERROR_ALREADY, BASS_ERROR_HANDLE, BASS_ERROR_INIT,
};
use crate::api::bass::bass_flags::*;
use crate::api::bass::bass_func::*;
use crate::api::bass::bassfx_func::*;
use crate::api::bass::basswasapi_func::*;
use crate::frb_generated::StreamSink;
use core::ffi::{c_uint, c_void};
use libloading::{Library, Symbol};
use once_cell::sync::{Lazy, OnceCell};
use std::ffi::{c_double, OsStr};
use std::os::windows::ffi::OsStrExt;
use std::path::PathBuf;
use std::ptr::null_mut;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::Duration;
use std::{env, iter, thread};

pub mod bass_errs;
pub mod bass_flags;
pub mod bass_func;
pub mod bassfx_func;
pub mod basswasapi_func;

struct BassApi {
    init: Symbol<'static, BASS_Init>,
    get_attr: Symbol<'static, BASS_ChannelGetAttribute>,
    set_attr: Symbol<'static, BASS_ChannelSetAttribute>,
    slide_attr: Symbol<'static, BASS_ChannelSlideAttribute>,
    wasapi_get_info: Symbol<'static, BASS_WASAPI_GetInfo>,
    stream_create: Symbol<'static, BASS_StreamCreateFile>,
    play: Symbol<'static, BASS_ChannelPlay>,
    pause: Symbol<'static, BASS_ChannelPause>,
    stop: Symbol<'static, BASS_ChannelStop>,
    chan_get_data: Symbol<'static, BASS_ChannelGetData>,
    chan_free: Symbol<'static, BASS_ChannelFree>,
    get_len: Symbol<'static, BASS_ChannelGetLength>,
    get_pos: Symbol<'static, BASS_ChannelGetPosition>,
    set_pos: Symbol<'static, BASS_ChannelSetPosition>,
    bytes2sec: Symbol<'static, BASS_ChannelBytes2Seconds>,
    sec2bytes: Symbol<'static, BASS_ChannelSeconds2Bytes>,
    is_active: Symbol<'static, BASS_ChannelIsActive>,
    stream_free: Symbol<'static, BASS_StreamFree>,
    free: Symbol<'static, BASS_Free>,
    error_get_code: Symbol<'static, BASS_ErrorGetCode>,
    wasapi_init: Symbol<'static, BASS_WASAPI_Init>,
    wasapi_free: Symbol<'static, BASS_WASAPI_Free>,
    bass_start: Symbol<'static, BASS_Start>,
    wasapi_start: Symbol<'static, BASS_WASAPI_Start>,
    wasapi_stop: Symbol<'static, BASS_WASAPI_Stop>,
    wasapi_is_started: Symbol<'static, BASS_WASAPI_IsStarted>,
    wasapi_get_data: Symbol<'static, BASS_WASAPI_GetData>,
    plugin_load: Symbol<'static, BASS_PluginLoad>,
    bass_set_sync: Symbol<'static, BASS_ChannelSetSync>,
    fx_tempo_create: Symbol<'static, BASS_FX_TempoCreate>,
    chan_set_fx: Symbol<'static, BASS_ChannelSetFX>,
    fx_set_params: Symbol<'static, BASS_FXSetParameters>,
    stream_handle: u32,
    path: Option<String>,
}

static BASS_API: Lazy<Mutex<Option<BassApi>>> = Lazy::new(|| Mutex::new(None));

static AUDIO_EVENT: Lazy<Mutex<Option<StreamSink<u32>>>> = Lazy::new(|| Mutex::new(None));

static PROGRESS_LISTEN: Lazy<Mutex<Option<StreamSink<f64>>>> = Lazy::new(|| Mutex::new(None));

static FREQ: Mutex<Option<u32>> = Mutex::new(Some(44100));
static CHANS: Mutex<Option<u32>> = Mutex::new(Some(2));

const WASAPI_BUFFER: f32 = 0.05;

static TARGET_VOLUME: Mutex<f32> = Mutex::new(1.0);
static TARGET_SPEED: Mutex<f32> = Mutex::new(1.0);

const FADE_DURATION: u32 = 500;

const PLUGIN_NAME: [&str; 8] = [
    "bassflac.dll",
    "bassmidi.dll",
    "basswv.dll",
    "bassopus.dll",
    "bassdsd.dll",
    "bassalac.dll",
    "basswebm.dll",
    "bassape.dll",
];

const BASE_TICK: f32 = 20.0;

const USER_STOPPED: u32 = 0;
const USER_PLAYING: u32 = 1;
const USER_PAUSED: u32 = 2;
const USER_ENDED: u32 = 3;
// const USER_STALLED: u32 = 3;
// const USER_PAUSED_DEVICE: u32 = 4;

const F_BANDWIDTH: f32 = 12.0; // range: 1 ~ 36

const F_CENTER: [f32; 10] = [
    80.0, 100.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0,
]; // range: 80 ~ 16k in Windows

static TARGET_FGAINS: Mutex<[f32; 10]> = Mutex::new([0.0; 10]); // range: -12.0db ~ 12.0db

static EQ_HANDLES: Mutex<[u32; 10]> = Mutex::new([0; 10]);

static PROGRESS_THREAD_RUNNING: AtomicBool = AtomicBool::new(false);

static BASS_LIB: OnceCell<Library> = OnceCell::new();
static WASAPI_LIB: OnceCell<Library> = OnceCell::new();
static FX_LIB: OnceCell<Library> = OnceCell::new();

static WASEXCLUSIVE: AtomicBool = AtomicBool::new(false);

fn notify_state(state: u32) {
    if let Ok(lock) = AUDIO_EVENT.lock() {
        if let Some(sink) = lock.as_ref() {
            let _ = sink.add(state);
        }
    }
}

unsafe extern "C" fn on_end_sync(handle: c_uint, channel: c_uint, data: c_uint, user: *mut c_void) {
    notify_state(USER_ENDED);
}

fn calculate_dynamic_bandwidth_linear(f_center: f32) -> f32 {
    let min_freq = *F_CENTER.first().unwrap_or(&80.0);
    let max_freq = *F_CENTER.last().unwrap_or(&16000.0);
    let min_bandwidth = 8.0; // 对应 max_freq
    let max_bandwidth = 28.0; // 对应 min_freq

    let clamped_f_center = f_center.clamp(min_freq, max_freq);

    // 计算归一化因子 (0.0 到 1.0)
    // 当 f_center = min_freq 时，factor = 0.0
    // 当 f_center = max_freq 时，factor = 1.0
    let factor = (clamped_f_center - min_freq) / (max_freq - min_freq);

    // 在带宽范围内进行插值
    // 从 max_bandwidth 线性地减小到 min_bandwidth
    let bandwidth = max_bandwidth + (min_bandwidth - max_bandwidth) * factor;

    bandwidth.clamp(1.0, 36.0)
}

impl BassApi {
    fn load() -> Result<Self, String> {
        let current_exe = env::current_exe().unwrap();
        let bass_dll_dir = current_exe
            .parent()
            .unwrap()
            .join("BASSDLL")
            .join("bass.dll");
        let basswasapi_dll_dir = current_exe
            .parent()
            .unwrap()
            .join("BASSDLL")
            .join("basswasapi.dll");

        let bassfx_dll_dir = current_exe
            .parent()
            .unwrap()
            .join("BASSDLL")
            .join("bass_fx.dll");

        unsafe {
            let lib: &Library = BASS_LIB
                .get_or_try_init(|| Library::new(&bass_dll_dir).map_err(|e| e.to_string()))?;

            let wasapi_lib: &Library = WASAPI_LIB
                .get_or_try_init(|| Library::new(&basswasapi_dll_dir).map_err(|e| e.to_string()))?;

            let fx_lib: &Library = FX_LIB
                .get_or_try_init(|| Library::new(&bassfx_dll_dir).map_err(|e| e.to_string()))?;

            let init = lib.get(b"BASS_Init\0").map_err(|e| e.to_string())?;

            let get_attr = lib
                .get(b"BASS_ChannelGetAttribute\0")
                .map_err(|e| e.to_string())?;

            let set_attr = lib
                .get(b"BASS_ChannelSetAttribute\0")
                .map_err(|e| e.to_string())?;

            let slide_attr = lib
                .get(b"BASS_ChannelSlideAttribute\0")
                .map_err(|e| e.to_string())?;

            let wasapi_get_info = wasapi_lib
                .get(b"BASS_WASAPI_GetInfo\0")
                .map_err(|e| e.to_string())?;

            let stream_create = lib
                .get(b"BASS_StreamCreateFile\0")
                .map_err(|e| e.to_string())?;

            let play = lib.get(b"BASS_ChannelPlay\0").map_err(|e| e.to_string())?;

            let pause = lib.get(b"BASS_ChannelPause\0").map_err(|e| e.to_string())?;

            let stop = lib.get(b"BASS_ChannelStop\0").map_err(|e| e.to_string())?;

            let chan_get_data = lib
                .get(b"BASS_ChannelGetData\0")
                .map_err(|e| e.to_string())?;

            let chan_free = lib.get(b"BASS_ChannelFree\0").map_err(|e| e.to_string())?;

            let get_len = lib
                .get(b"BASS_ChannelGetLength\0")
                .map_err(|e| e.to_string())?;

            let get_pos = lib
                .get(b"BASS_ChannelGetPosition\0")
                .map_err(|e| e.to_string())?;

            let set_pos = lib
                .get(b"BASS_ChannelSetPosition\0")
                .map_err(|e| e.to_string())?;

            let bytes2sec = lib
                .get(b"BASS_ChannelBytes2Seconds\0")
                .map_err(|e| e.to_string())?;

            let sec2bytes = lib
                .get(b"BASS_ChannelSeconds2Bytes\0")
                .map_err(|e| e.to_string())?;

            let is_active = lib
                .get(b"BASS_ChannelIsActive\0")
                .map_err(|e| e.to_string())?;

            let stream_free = lib.get(b"BASS_StreamFree\0").map_err(|e| e.to_string())?;

            let error_get_code = lib.get(b"BASS_ErrorGetCode\0").map_err(|e| e.to_string())?;

            let free = lib.get(b"BASS_Free\0").map_err(|e| e.to_string())?;

            let wasapi_init = wasapi_lib
                .get(b"BASS_WASAPI_Init\0")
                .map_err(|e| e.to_string())?;

            let wasapi_free = wasapi_lib
                .get(b"BASS_WASAPI_Free\0")
                .map_err(|e| e.to_string())?;

            let bass_start = lib.get(b"BASS_Start\0").map_err(|e| e.to_string())?;

            let wasapi_start = wasapi_lib
                .get(b"BASS_WASAPI_Start\0")
                .map_err(|e| e.to_string())?;

            let wasapi_stop = wasapi_lib
                .get(b"BASS_WASAPI_Stop\0")
                .map_err(|e| e.to_string())?;

            let wasapi_is_started = wasapi_lib
                .get(b"BASS_WASAPI_IsStarted\0")
                .map_err(|e| e.to_string())?;

            let wasapi_get_data = wasapi_lib
                .get(b"BASS_WASAPI_GetData\0")
                .map_err(|e| e.to_string())?;

            let plugin_load = lib.get(b"BASS_PluginLoad\0").map_err(|e| e.to_string())?;

            let bass_set_sync = lib
                .get(b"BASS_ChannelSetSync\0")
                .map_err(|e| e.to_string())?;

            let fx_tempo_create = fx_lib
                .get(b"BASS_FX_TempoCreate\0")
                .map_err(|e| e.to_string())?;

            let chan_set_fx = lib.get(b"BASS_ChannelSetFX\0").map_err(|e| e.to_string())?;

            let fx_set_params = lib
                .get(b"BASS_FXSetParameters\0")
                .map_err(|e| e.to_string())?;

            Ok(Self {
                init,
                get_attr,
                set_attr,
                slide_attr,
                wasapi_get_info,
                stream_free,
                free,
                stream_create,
                play,
                pause,
                stop,
                chan_get_data,
                chan_free,
                get_len,
                get_pos,
                set_pos,
                bytes2sec,
                sec2bytes,
                is_active,
                error_get_code,
                wasapi_init,
                wasapi_free,
                bass_start,
                wasapi_start,
                wasapi_stop,
                wasapi_is_started,
                wasapi_get_data,
                plugin_load,
                bass_set_sync,
                fx_tempo_create,
                chan_set_fx,
                fx_set_params,
                stream_handle: 0,
                path: None,
            })
        }
    }

    fn get_wasapi_info(&mut self) -> Result<(), String> {
        let mut info = BASS_WASAPI_INFO::default();
        unsafe {
            (self.wasapi_free)();
        };
        let result =
            unsafe { (self.wasapi_init)(-1, 0, 0, 0, WASAPI_BUFFER, 0.0, null_mut(), null_mut()) };
        self.or_err_(result)?;
        let ok = unsafe { (self.wasapi_get_info)(&mut info) };
        self.or_err_(ok)?;
        unsafe {
            *FREQ.lock().unwrap() = Some(info.freq);
            *CHANS.lock().unwrap() = Some(info.chans);
            (self.wasapi_free)();
        }
        Ok(())
    }

    fn bass_init(&mut self) -> Result<(), String> {
        unsafe {
            (self.free)();
        };
        self.get_wasapi_info()?;
        unsafe {
            (self.wasapi_free)();
        };
        let result = unsafe {
            (self.init)(
                1,
                FREQ.lock().unwrap().unwrap_or(44100),
                BASS_DEVICE_REINIT,
                null_mut(),
                null_mut(),
            )
        };

        let current_exe = env::current_exe().unwrap();

        unsafe {
            for i in PLUGIN_NAME {
                let addons_path = current_exe.parent().unwrap().join("BASSDLL").join(i);

                let path: Vec<u16> = OsStr::new(&addons_path)
                    .encode_wide()
                    .chain(iter::once(0))
                    .collect();

                let r = (self.plugin_load)(path.as_ptr() as *const _, BASS_UNICODE);
                self.or_err_(r as i32)?;
            }
        };

        self.or_err_(result)
    }

    fn get_volume(&self) -> Result<f32, String> {
        let mut vol: f32 = 0.0;
        let ok =
            unsafe { (self.get_attr)(self.stream_handle, BASS_ATTRIB_VOL, &mut vol as *mut _) };
        if ok == 0 {
            let err_code = unsafe { (self.error_get_code)() };
            Err(get_err_info(err_code).unwrap())
        } else {
            Ok(vol)
        }
    }

    fn listen_progress(&self) {
        // 停止旧线程
        PROGRESS_THREAD_RUNNING.store(false, Ordering::SeqCst);
        PROGRESS_THREAD_RUNNING.store(true, Ordering::SeqCst);
        thread::spawn(|| {
            if let Some(sink) = PROGRESS_LISTEN.lock().unwrap().as_ref() {
                while PROGRESS_THREAD_RUNNING.load(Ordering::SeqCst) {
                    thread::sleep(Duration::from_millis(
                        (BASE_TICK / *TARGET_SPEED.lock().unwrap()) as u64,
                    ));
                    if let Ok(mut api_lock) = BASS_API.lock() {
                        if let Some(api) = api_lock.as_mut() {
                            if api.stream_handle != 0 {
                                let _ = sink.add(api.get_pos());
                            }
                        }
                    }
                }
            }
        });
    }

    fn set_volume(&mut self, mut vol: f32) -> Result<(), String> {
        vol = vol.clamp(0.0, 1.0);
        *TARGET_VOLUME.lock().unwrap() = vol;
        let ok = unsafe {
            if self.stream_handle == 0 {
                return Ok(());
            }
            (self.set_attr)(self.stream_handle, BASS_ATTRIB_VOL, vol) //BASS_ATTRIB_VOL:2
        };
        self.or_err_(ok)
    }

    fn fade_in(&mut self) -> Result<(), String> {
        let ok = unsafe {
            if self.stream_handle == 0 {
                return Ok(());
            }
            (self.slide_attr)(self.stream_handle, BASS_ATTRIB_VOL, -1.0, 0);
            (self.set_attr)(self.stream_handle, BASS_ATTRIB_VOL, 0.0) //BASS_ATTRIB_VOL:2
        };
        self.or_err_(ok)?;
        unsafe {
            let result = (self.slide_attr)(
                self.stream_handle,
                BASS_ATTRIB_VOL,
                *TARGET_VOLUME.lock().unwrap(),
                FADE_DURATION,
            );
            self.or_err_(result)
        }
    }

    fn fade_out(&mut self) -> Result<(), String> {
        if self.stream_handle == 0 { return Ok(()); }
        unsafe {
            let result = (self.slide_attr)(self.stream_handle, BASS_ATTRIB_VOL, 0.0, FADE_DURATION);
            thread::sleep(Duration::from_millis(FADE_DURATION as u64));
            self.or_err_(result)
        }
    }

    fn set_sync(&mut self, sync_type: u32, call_back: SYNCPROC) -> Result<(), String> {
        unsafe {
            let sync_handle =
                (self.bass_set_sync)(self.stream_handle, sync_type, 0, call_back, null_mut());
            self.or_err_(sync_handle as i32)
        }
    }

    fn create_stream(&mut self, path: String) -> Result<(), String> {
        self.stop()?;
        self.chan_free();
        let wide: Vec<u16> = OsStr::new(&path)
            .encode_wide()
            .chain(iter::once(0))
            .collect();

        let handle = unsafe {
            (self.stream_create)(
                0,
                wide.as_ptr() as *const c_void,
                0,
                0,
                BASS_UNICODE | BASS_ASYNCFILE | BASS_STREAM_DECODE | BASS_SAMPLE_FLOAT,
            )
        };

        self.or_err_(handle as i32)?;

        let fx_flag = if WASEXCLUSIVE.load(Ordering::SeqCst) {
            BASS_FX_FREESOURCE | BASS_STREAM_DECODE
        } else {
            BASS_FX_FREESOURCE
        };
        let fx_handle = unsafe { (self.fx_tempo_create)(handle, fx_flag) };
        self.or_err_(fx_handle as i32)?;
        self.stream_handle = fx_handle;
        self.set_sync(BASS_SYNC_END, Some(on_end_sync))?;
        self.set_all_eq_params();
        Ok(())
    }

    fn play_file(&mut self, path: String) -> Result<(), String> {
        self.create_stream(path.clone())?;
        self.path = Some(path);
        self.resume()
    }

    fn set_all_eq_params(&mut self) {
        unsafe {
            if self.stream_handle == 0 {
                return;
            }
            let mut eq_params = BASS_DX8_PARAMEQ::default();
            for (index, center_fre) in F_CENTER.into_iter().enumerate() {
                let eq = (self.chan_set_fx)(self.stream_handle, BASS_FX_DX8_PARAMEQ, 0); // maybe replace self.stream_handle or set priority
                if eq == 0 {
                    let err_code = (self.error_get_code)();
                    println!(
                        "{}",
                        get_err_info(err_code).unwrap_or_else(|| format!(
                            "Unknown BASS error | ERR_CODE<{}>",
                            err_code
                        ))
                    );
                    return;
                }
                eq_params.fCenter = center_fre;
                eq_params.fBandwidth = calculate_dynamic_bandwidth_linear(center_fre);
                eq_params.fGain = TARGET_FGAINS.lock().unwrap()[index];
                let params_ptr = &eq_params as *const BASS_DX8_PARAMEQ as *const c_void;
                let ok = (self.fx_set_params)(eq, params_ptr);
                if ok == 0 {
                    let err_code = (self.error_get_code)();
                    println!(
                        "{}",
                        get_err_info(err_code).unwrap_or_else(|| format!(
                            "Unknown BASS error | ERR_CODE<{}>",
                            err_code
                        ))
                    );
                    continue;
                }
                if let Ok(mut handles) = EQ_HANDLES.lock() {
                    handles[index] = eq;
                } else {
                    println!("Failed to acquire lock on EQ_HANDLES.");
                }
            }
        };
    }

    fn set_eq_params(&mut self, fre_center_index: i32, gain: f32) {
        let gain = gain.clamp(-12.0, 12.0);
        let fre_center_index = fre_center_index as usize;
        if let Ok(mut gains) = TARGET_FGAINS.lock() {
            gains[fre_center_index] = gain;
        } else {
            eprintln!("Failed to acquire lock on TARGET_FGAINS.");
        }
        unsafe {
            if self.stream_handle == 0 || !(0..F_CENTER.len()).contains(&fre_center_index) {
                return;
            }
            let eq_params = BASS_DX8_PARAMEQ {
                fCenter: F_CENTER[fre_center_index],
                fBandwidth: calculate_dynamic_bandwidth_linear(F_CENTER[fre_center_index]),
                fGain: gain,
            };
            let params_ptr = &eq_params as *const BASS_DX8_PARAMEQ as *const c_void;
            let ok = (self.fx_set_params)(EQ_HANDLES.lock().unwrap()[fre_center_index], params_ptr);
            if ok == 0 {
                let err_code = (self.error_get_code)();
                println!(
                    "{}",
                    get_err_info(err_code)
                        .unwrap_or_else(|| format!("Unknown BASS error | ERR_CODE<{}>", err_code))
                );
            }
        }
    }

    fn resume(&mut self) -> Result<(), String> {
        if WASEXCLUSIVE.load(Ordering::SeqCst) {
            self.apply_wasapi_init()?;
            let active = unsafe { (self.wasapi_is_started)() };
            if active == TRUE {
                return Ok(());
            }
            let result = unsafe { (self.wasapi_start)() };
            self.or_err_(result)?;
        } else {
            let result = unsafe { (self.bass_start)() };
            self.or_err_(result)?;
            let result = unsafe { (self.play)(self.stream_handle, FALSE) };
            self.fade_in()?;
            self.or_err_(result)?;
        }
        notify_state(USER_PLAYING);
        Ok(())
    }

    fn pause(&mut self) -> Result<(), String> {
        notify_state(USER_PAUSED);
        if WASEXCLUSIVE.load(Ordering::SeqCst) {
            let active = unsafe { (self.wasapi_is_started)() };
            if active == FALSE {
                return Ok(());
            }
            let result = unsafe { (self.wasapi_stop)(FALSE) };
            self.or_err_(result)?;
        } else {
            self.fade_out()?;
            let result = unsafe { (self.pause)(self.stream_handle) };
            self.or_err_(result)?;
        }
        Ok(())
    }

    fn stop(&mut self) -> Result<(), String> {
        if self.stream_handle == 0 {
            return Ok(());
        }

        if WASEXCLUSIVE.load(Ordering::SeqCst) {
            let active = unsafe { (self.wasapi_is_started)() };
            if active == FALSE {
                return Ok(());
            }
            let result = unsafe { (self.wasapi_stop)(TRUE) };
            self.or_err_(result)?;
        } else {
            self.fade_out()?;
            let result = unsafe { (self.stop)(self.stream_handle) };
            self.or_err_(result)?;
        }
        notify_state(USER_STOPPED);
        Ok(())
    }

    fn chan_get_data(&mut self) -> Option<Vec<f32>> {
        if self.stream_handle == 0 {
            return None;
        }
        let data_size = 256; // 512点FFT返回 256个值
        let mut buffer = vec![0.0f32; data_size];
        let buffer_ptr = buffer.as_mut_ptr() as *mut c_void;
        unsafe {
            let ok = (self.chan_get_data)(self.stream_handle, buffer_ptr, BASS_DATA_FFT512);
            if ok == 0 {
                let err_code = (self.error_get_code)();
                println!(
                    "{}",
                    get_err_info(err_code)
                        .unwrap_or_else(|| format!("Unknown BASS error | ERR_CODE<{}>", err_code))
                );
                return None;
            }
        };

        if buffer.len() != data_size {
            buffer.resize(data_size, 0.0f32);
        }

        // 对数缩放
        let log_gain_multiplier = 1000.0; // 调高这个值可以更早地看到低幅度变化
        let log_offset = 1.0; // 避免 log(0)，并提供一个基础值

        for v in &mut buffer {
            let transformed_val = (v.abs() * log_gain_multiplier + log_offset).log10();
            *v = transformed_val;
        }

        let min_val = buffer.clone().into_iter().reduce(f32::min).unwrap_or(0.0);
        let max_val = buffer.clone().into_iter().reduce(f32::max).unwrap_or(1.0);
        let range = max_val - min_val;

        for v in &mut buffer {
            let percentage = if range > 0.0f32 {
                // 避免除以零
                ((*v - min_val) / range).clamp(0.0, 1.0)
            } else {
                0.0
            };
            *v = percentage;
        }

        Some(buffer)
    }

    fn toggle(&mut self) -> Result<(), String> {
        if let Some(state) = self.get_state() {
            match state {
                BASS_ACTIVE_STOPPED | BASS_ACTIVE_PAUSED_DEVICE => {
                    unsafe { (self.bass_start)() };
                    Ok(self.resume()?)
                }
                BASS_ACTIVE_PLAYING => Ok(self.pause()?),
                BASS_ACTIVE_PAUSED => Ok(self.resume()?),
                _ => Ok(()),
            }
        } else {
            Ok(())
        }
    }

    fn get_len(&mut self) -> f64 {
        if self.stream_handle == 0 {
            return 0.0;
        }

        let len_bytes = unsafe { (self.get_len)(self.stream_handle, BASS_POS_BYTE) };
        let err_code = unsafe { (self.error_get_code)() };
        if err_code != 0 {
            if err_code == BASS_ERROR_HANDLE {
                self.chan_free();
            }
            println!("BASS failed, error code: {}", err_code);
            0.0
        } else {
            unsafe { (self.bytes2sec)(self.stream_handle, len_bytes) }
        }
    }

    fn get_pos(&mut self) -> f64 {
        if self.stream_handle == 0 {
            return 0.0;
        }

        let pos_bytes = unsafe { (self.get_pos)(self.stream_handle, BASS_POS_BYTE) };
        if pos_bytes == !0 {
            let err_code = unsafe { (self.error_get_code)() };
            if err_code == BASS_ERROR_HANDLE {
                self.chan_free();
            }
            println!("BASS failed, error code: {}", err_code);
            0.0
        } else {
            let mut final_bytes = pos_bytes;
            if WASEXCLUSIVE.load(Ordering::Relaxed) {
                let decode_bytes =
                    unsafe { (self.wasapi_get_data)(null_mut(), BASS_DATA_AVAILABLE) }; // 获取解码进度
                if decode_bytes > 0 && decode_bytes != !0 {
                    final_bytes = final_bytes.saturating_sub(decode_bytes as u64);// 真实进度 = 解码进度 - 缓冲区残留
                }
            }
            unsafe { (self.bytes2sec)(self.stream_handle, final_bytes) }.max(0.0)
        }
    }

    fn set_pos(&mut self, pos: f64) -> Result<(), String> {
        if self.stream_handle == 0 {
            return Ok(());
        }
        self.fade_out()?;
        let bytes = unsafe { (self.sec2bytes)(self.stream_handle, pos) };
        unsafe { (self.set_pos)(self.stream_handle, bytes, BASS_POS_BYTE) };
        self.fade_in()?;
        let err_code = unsafe { (self.error_get_code)() };
        self.or_err_(err_code)
    }

    fn set_speed(&mut self, mut speed: f32) {
        speed = speed.clamp(0.5, 2.0);
        *TARGET_SPEED.lock().unwrap() = speed;
        let ok = unsafe {
            if self.stream_handle == 0 {
                *TARGET_SPEED.lock().unwrap() = 1.0;
                return;
            }
            (self.set_attr)(self.stream_handle, BASS_ATTRIB_TEMPO, (speed - 1.0) * 100.0)
        };
        if ok == 0 {
            *TARGET_SPEED.lock().unwrap() = 1.0;
            let err_code = unsafe { (self.error_get_code)() };
            println!(
                "{}",
                get_err_info(err_code)
                    .unwrap_or_else(|| format!("Unknown BASS error | ERR_CODE<{}>", err_code))
            );
        }
    }

    fn get_state(&self) -> Option<u32> {
        if self.stream_handle == 0 {
            None
        } else if WASEXCLUSIVE.load(Ordering::SeqCst) {
            let active = unsafe { (self.wasapi_is_started)() };
            if active == TRUE {
                Some(BASS_ACTIVE_PLAYING)
            } else {
                Some(BASS_ACTIVE_PAUSED)
            }
        } else {
            Some(unsafe { (self.is_active)(self.stream_handle) })
        }
    }

    fn stream_free(&mut self) {
        if self.stream_handle != 0 {
            unsafe { (self.stream_free)(self.stream_handle) };
            self.stream_handle = 0;
        }
    }

    fn chan_free(&mut self) {
        if self.stream_handle != 0 {
            unsafe {
                (self.chan_free)(self.stream_handle);
                (self.wasapi_free)();
            };
            self.stream_handle = 0;
        }
        notify_state(USER_STOPPED);
    }

    fn or_err_(&mut self, result: i32) -> Result<(), String> {
        if result == 0 {
            let err_code = unsafe { (self.error_get_code)() };
            if err_code == 0 {
                Ok(())
            } else {
                if err_code == BASS_ERROR_HANDLE {
                    self.chan_free();
                }

                let err_str = get_err_info(err_code)
                    .unwrap_or_else(|| format!("Unknown BASS error | ERR_CODE<{}>", err_code));
                println!("{}", err_str);
                Err(err_str)
            }
        } else {
            Ok(())
        }
    }

    fn switch_exclusive_mode(&mut self, exclusive: bool) -> Result<(), String> {
        unsafe {
            (self.wasapi_free)();
        }
        let last_pos = self.get_pos();
        WASEXCLUSIVE.store(exclusive, Ordering::SeqCst);
        let path = self.path.clone();

        if self.stream_handle != 0 && path.is_some() {
            self.create_stream(path.unwrap_or("".to_string()))?;
            self.set_pos(last_pos)?;
            self.resume()?
        }
        Ok(())
    }

    fn apply_wasapi_init(&mut self) -> Result<(), String> {
        unsafe {
            (self.wasapi_free)();
        }
        let flags = if WASEXCLUSIVE.load(Ordering::SeqCst) {
            BASS_WASAPI_EXCLUSIVE | BASS_WASAPI_AUTOFORMAT | BASS_WASAPI_EVENT
        } else {
            0
        };

        let result = unsafe {
            (self.wasapi_init)(
                -1,
                0,
                0,
                flags,
                WASAPI_BUFFER,
                0.0,
                WASAPIPROC_BASS,
                self.stream_handle as *mut c_void,
            )
        };
        self.or_err_(result)
    }
}

impl Drop for BassApi {
    fn drop(&mut self) {
        unsafe {
            (self.free)();
            (self.wasapi_free)();
            PROGRESS_THREAD_RUNNING.store(false, Ordering::SeqCst);
            notify_state(USER_STOPPED);
        }
    }
}

#[flutter_rust_bridge::frb]
pub fn load_lib() -> Result<(), String> {
    *BASS_API.lock().unwrap() = Some(BassApi::load()?);
    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn init_bass() -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().bass_init()
}

#[flutter_rust_bridge::frb]
pub fn audio_event_stream(sink: StreamSink<u32>) {
    *AUDIO_EVENT.lock().unwrap() = Some(sink);
}

#[flutter_rust_bridge::frb]
pub fn progress_listen(sink: StreamSink<f64>) {
    *PROGRESS_LISTEN.lock().unwrap() = Some(sink);
    BASS_API.lock().unwrap().as_ref().unwrap().listen_progress();
}

#[flutter_rust_bridge::frb]
pub fn switch_exclusive_mode(exclusive: bool) -> Result<(), String> {
    BASS_API
        .lock()
        .unwrap()
        .as_mut()
        .unwrap()
        .switch_exclusive_mode(exclusive)
}

#[flutter_rust_bridge::frb]
pub fn play_file(path: String) -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().play_file(path)
}

#[flutter_rust_bridge::frb]
pub fn resume() -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().resume()
}

#[flutter_rust_bridge::frb]
pub fn pause() -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().pause()
}

#[flutter_rust_bridge::frb]
pub fn stop() -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().stop()
}

#[flutter_rust_bridge::frb]
pub fn get_len() -> f64 {
    BASS_API.lock().unwrap().as_mut().unwrap().get_len()
}

#[flutter_rust_bridge::frb]
pub fn get_position() -> f64 {
    BASS_API.lock().unwrap().as_mut().unwrap().get_pos()
}

#[flutter_rust_bridge::frb]
pub fn set_position(pos: f64) -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().set_pos(pos)
}

#[flutter_rust_bridge::frb]
pub fn toggle() -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().toggle()
}

#[flutter_rust_bridge::frb]
pub fn get_volume() -> Result<f32, String> {
    BASS_API.lock().unwrap().as_ref().unwrap().get_volume()
}

#[flutter_rust_bridge::frb]
pub fn set_volume(vol: f32) -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().set_volume(vol)
}

#[flutter_rust_bridge::frb]
pub fn set_speed(speed: f32) {
    BASS_API.lock().unwrap().as_mut().unwrap().set_speed(speed)
}

#[flutter_rust_bridge::frb]
pub fn set_eq_params(fre_center_index: i32, gain: f32) {
    BASS_API
        .lock()
        .unwrap()
        .as_mut()
        .unwrap()
        .set_eq_params(fre_center_index, gain)
}

#[flutter_rust_bridge::frb]
pub fn get_chan_data() -> Option<Vec<f32>> {
    BASS_API.lock().unwrap().as_mut().unwrap().chan_get_data()
}
