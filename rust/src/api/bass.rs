use crate::api::bass::bass_flags::*;
use crate::api::bass::bass_func::*;
use crate::api::bass::basswasapi_func::*;
use core::ffi::c_void;
use libloading::{Library, Symbol};
use once_cell::sync::Lazy;
use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use std::ptr::null_mut;
use std::sync::Mutex;
use std::time::Duration;
use std::{env, iter, thread};
use crate::api::bass::bass_errs::get_err_info;

pub mod bass_flags;
pub mod bass_func;
pub mod basswasapi_func;
pub mod bass_errs;

struct BassApi {
    _lib: &'static Library,
    _wasapi_lib: &'static Library,
    init: Symbol<'static, BASS_Init>,
    get_attr: Symbol<'static, BASS_ChannelGetAttribute>,
    set_attr: Symbol<'static, BASS_ChannelSetAttribute>,
    slide_attr:Symbol<'static,BASS_ChannelSlideAttribute>,
    wasapi_get_info: Symbol<'static, BASS_WASAPI_GetInfo>,
    stream_create: Symbol<'static, BASS_StreamCreateFile>,
    play: Symbol<'static, BASS_ChannelPlay>,
    pause: Symbol<'static, BASS_ChannelPause>,
    stop: Symbol<'static, BASS_ChannelStop>,
    get_pos:Symbol<'static,BASS_ChannelGetPosition>,
    set_pos:Symbol<'static,BASS_ChannelSetPosition>,
    bytes2sec:Symbol<'static,BASS_ChannelBytes2Seconds>,
    sec2bytes:Symbol<'static,BASS_ChannelSeconds2Bytes>,
    is_active: Symbol<'static, BASS_ChannelIsActive>,
    stream_free: Symbol<'static, BASS_StreamFree>,
    free: Symbol<'static, BASS_Free>,
    error_get_code: Symbol<'static, BASS_ErrorGetCode>,
    wasapi_init: Symbol<'static, BASS_WASAPI_Init>,
    wasapi_free: Symbol<'static, BASS_WASAPI_Free>,
    bass_start: Symbol<'static, BASS_Start>,
    wasapi_start: Symbol<'static, BASS_WASAPI_Start>,
    plugin_load: Symbol<'static, BASS_PluginLoad>,
    stream_handle: u32,
}

static BASS_API: Lazy<Mutex<Option<BassApi>>> = Lazy::new(|| Mutex::new(None));

static FREQ: Mutex<Option<u32>> = Mutex::new(Some(44100));
static CHANS: Mutex<Option<u32>> = Mutex::new(Some(2));

const WASAPI_BUFFER: f32 = 0.05;

static TARGET_VOLUME: Mutex<f32> =  Mutex::new(1.0);

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

        unsafe {
            let lib: &'static Library = Box::leak(Box::new(
                Library::new(&bass_dll_dir).map_err(|e| e.to_string())?,
            ));
            let wasapi_lib: &'static Library = Box::leak(Box::new(
                Library::new(&basswasapi_dll_dir).map_err(|e| e.to_string())?,
            ));

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

            let get_pos=lib.get(b"BASS_ChannelGetPosition\0").map_err(|e| e.to_string())?;
            
            let set_pos=lib.get(b"BASS_ChannelSetPosition\0").map_err(|e| e.to_string())?;
            
            let bytes2sec=lib.get(b"BASS_ChannelBytes2Seconds\0").map_err(|e| e.to_string())?;
            
            let sec2bytes=lib.get(b"BASS_ChannelSeconds2Bytes\0").map_err(|e| e.to_string())?;
            
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

            let plugin_load = lib.get(b"BASS_PluginLoad\0").map_err(|e| e.to_string())?;

            Ok(Self {
                _lib: lib,
                _wasapi_lib: wasapi_lib,
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
                plugin_load,
                stream_handle: 0,
            })
        }
    }

    fn get_wasapi_info(&self) -> Result<(), String> {
        let mut info = BASS_WASAPI_INFO::default();
        unsafe {
            (self.wasapi_free)();
        };
        let result = unsafe { (self.wasapi_init)(-1, 0, 0, 0, 0.05, 0.0, None, null_mut()) };
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

    fn bass_init(&self) -> Result<(), String> {
        unsafe {
            (self.free)();
        };
        self.get_wasapi_info()?;
        unsafe {
            (self.wasapi_free)();
        };
        let result = unsafe { (self.init)(-1, FREQ.lock().unwrap().unwrap_or(44100), 0, null_mut(), null_mut()) };
        unsafe {
            (self.bass_start)();
        };

        let current_exe = env::current_exe().unwrap();

        unsafe {
            for i in PLUGIN_NAME {
                let addons_path = current_exe.parent().unwrap().join("BASSDLL").join(i);

                let path: Vec<u16> = OsStr::new(&addons_path)
                    .encode_wide()
                    .chain(std::iter::once(0))
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
    
    fn set_volume(&self, mut vol: f32) -> Result<(), String> {
        vol = vol.clamp(0.0, 1.0);
        *TARGET_VOLUME.lock().unwrap() = vol;
        let ok = unsafe {
            if self.stream_handle==0 {
            return Ok(());
        }
            (self.set_attr)(self.stream_handle, BASS_ATTRIB_VOL, vol) //BASS_ATTRIB_VOL:2
        };
        self.or_err_(ok)
    }

    fn fade_in(&self) -> Result<(), String> {
         if self.stream_handle==0 {
            return Ok(());
        }
        unsafe {
            let result=(self.slide_attr)(self.stream_handle,BASS_ATTRIB_VOL,*TARGET_VOLUME.lock().unwrap(),FADE_DURATION);
            self.or_err_(result)
        }
    }

    fn fade_out(&self) -> Result<(), String> {
        if self.stream_handle==0 {
            return Ok(());
        }
        unsafe {
            let result=(self.slide_attr)(self.stream_handle,BASS_ATTRIB_VOL,0.0,FADE_DURATION);
            self.or_err_(result)
        }
    }

    fn play_file(&mut self, path: String) -> Result<(), String> {
        self.fade_out()?;
        thread::sleep(Duration::from_millis(FADE_DURATION as u64));
        self.stream_free();
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
                BASS_UNICODE | BASS_ASYNCFILE | BASS_STREAM_AUTOFREE | BASS_SAMPLE_FLOAT,
            )
        };

        self.or_err_(handle as i32)?;
        self.stream_handle = handle;
        self.resume()?;
        Ok(())
    }

    fn resume(&self) -> Result<(), String> {
        if let Some(state) = self.get_state() {
            if state == BASS_ACTIVE_PLAYING {
            return Ok(());
        }
        }else { 
            return Ok(());
        }

        let result = unsafe { (self.play)(self.stream_handle, 0) };
        self.fade_in()?;
        self.or_err_(result)
    }

    fn pause(&self) -> Result<(), String> {
        if let Some(state) = self.get_state() {
            if state == BASS_ACTIVE_PAUSED {
            return Ok(());
        }
        }else { 
            return Ok(());
        }
        
        self.fade_out()?;
        thread::sleep(Duration::from_millis(FADE_DURATION as u64));
        let result = unsafe { (self.pause)(self.stream_handle) };
        self.or_err_(result)
    }

    fn stop(&self) -> Result<(), String> {
        if self.stream_handle==0 {
            return Ok(());
        }
        
        self.fade_out()?;
        thread::sleep(Duration::from_millis(FADE_DURATION as u64));
        let result = unsafe { (self.stop)(self.stream_handle) };
        self.or_err_(result)
    }

    fn toggle(&self) -> Result<(), String> {
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
        }else { 
            Ok(())
        }
        
    }
    
    fn get_pos(&self)-> f64{
        if self.stream_handle==0 {
            return 0.0;
        }
        
        let pos = unsafe { (self.get_pos)(self.stream_handle,BASS_POS_BYTE) };
        let err_code = unsafe { (self.error_get_code)() };
        if err_code != 0 {
            println!("BASS failed, error code: {}", err_code);
            0.0
        }else { 
            unsafe{(self.bytes2sec)(self.stream_handle,pos)}
        }
    }
    
    fn set_pos(&self, pos: f64) {
        if self.stream_handle==0 {
            return;
        }
        
        let bytes=unsafe{(self.sec2bytes)(self.stream_handle,pos)};
        unsafe { (self.set_pos)(self.stream_handle,bytes,BASS_POS_BYTE) };
        let err_code = unsafe { (self.error_get_code)() };
        if err_code != 0 {
            println!("BASS failed, error code: {}", err_code);
        }
    }

    fn get_state(&self) -> Option<u32> {
        if self.stream_handle==0 {
            None
        }else { 
            Some(unsafe { (self.is_active)(self.stream_handle) })
        }
    }

    fn stream_free(&mut self) {
        if self.stream_handle != 0 {
            unsafe { (self.stream_free)(self.stream_handle) };
            self.stream_handle = 0;
        }
    }

    fn or_err_(&self, result: i32) -> Result<(), String> {
        if result == 0 {
            let err_code = unsafe { (self.error_get_code)() };
            if err_code==0 { 
                Ok(())
            }else { 
                Err(get_err_info(err_code).unwrap_or_else(|| format!("Unknown BASS error | ERR_CODE<{}>", err_code)))
            }
        } else {
            Ok(())
        }
    }

    ///有大问题
    fn set_exclusive_mode(&self, exclusive: bool) -> Result<(), String> {
        unsafe {
            (self.wasapi_free)();
        };

        let mut flags = 0;
        if exclusive {
            flags |= BASS_WASAPI_EXCLUSIVE;
        }

        let result = unsafe {
            (self.wasapi_init)(
                -1,
                FREQ.lock().unwrap().unwrap_or(44100),
                CHANS.lock().unwrap().unwrap_or(2),
                flags,
                WASAPI_BUFFER,
                0.0,
                None,
                self.stream_handle as *mut c_void,
            )
        };

        // let was_result = unsafe { (self.wasapi_start)() };
        // let err_code = unsafe { (self.error_get_code)() };
        // println!("was_result:{}", err_code);

        self.or_err_(result)
    }
}

impl Drop for BassApi {
    fn drop(&mut self) {
        unsafe {
            (self.free)();
            (self.wasapi_free)();
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
    BASS_API.lock().unwrap().as_ref().unwrap().bass_init()
}

#[flutter_rust_bridge::frb]
pub fn set_exclusive_mode(exclusive: bool) -> Result<(), String> {
    BASS_API
        .lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .set_exclusive_mode(exclusive)
}

#[flutter_rust_bridge::frb]
pub fn play_file(path: String) -> Result<(), String> {
    BASS_API.lock().unwrap().as_mut().unwrap().play_file(path)
}

#[flutter_rust_bridge::frb]
pub fn resume() -> Result<(), String> {
    BASS_API.lock().unwrap().as_ref().unwrap().resume()
}

#[flutter_rust_bridge::frb]
pub fn pause() -> Result<(), String> {
    BASS_API.lock().unwrap().as_ref().unwrap().pause()
}

#[flutter_rust_bridge::frb]
pub fn stop() -> Result<(), String> {
    BASS_API.lock().unwrap().as_ref().unwrap().stop()
}

#[flutter_rust_bridge::frb]
pub fn get_position() -> f64 {
    BASS_API.lock().unwrap().as_ref().unwrap().get_pos()
}

#[flutter_rust_bridge::frb]
pub fn set_position(pos: f64) {
    BASS_API.lock().unwrap().as_ref().unwrap().set_pos(pos)
}

#[flutter_rust_bridge::frb]
pub fn toggle() -> Result<(), String> {
    BASS_API.lock().unwrap().as_ref().unwrap().toggle()
}

#[flutter_rust_bridge::frb]
pub fn get_volume() -> Result<f32, String> {
    BASS_API.lock().unwrap().as_ref().unwrap().get_volume()
}

#[flutter_rust_bridge::frb]
pub fn set_volume(vol: f32) -> Result<(), String> {
    BASS_API.lock().unwrap().as_ref().unwrap().set_volume(vol)
}
