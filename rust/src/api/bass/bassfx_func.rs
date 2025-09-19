use std::ffi::c_uint;

pub(crate) type BASS_FX_TempoCreate = unsafe extern "C" fn(chan: c_uint, flags: c_uint) -> c_uint;

pub const BASS_FX_FREESOURCE: u32 = 0x10000;

pub const BASS_ATTRIB_TEMPO: u32 = 0x10000;
