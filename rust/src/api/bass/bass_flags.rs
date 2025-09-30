pub const BASS_SAMPLE_FLOAT: u32 = 256;

pub const BASS_STREAM_AUTOFREE: u32 = 0x40000;
pub const BASS_STREAM_DECODE: u32 = 0x200000;

pub const BASS_ASYNCFILE: u32 = 0x40000000;
pub const BASS_UNICODE: u32 = 0x80000000;

pub const BASS_ATTRIB_VOL: u32 = 2;

pub const BASS_ACTIVE_STOPPED: u32 = 0;
pub const BASS_ACTIVE_PLAYING: u32 = 1;
pub const BASS_ACTIVE_STALLED: u32 = 2;
pub const BASS_ACTIVE_PAUSED: u32 = 3;
pub const BASS_ACTIVE_PAUSED_DEVICE: u32 = 4;

pub const BASS_POS_BYTE: u32 = 0;

pub const BASS_WASAPI_EXCLUSIVE: u32 = 1;
pub const BASS_WASAPI_AUTOFORMAT: u32 = 2;
pub const BASS_WASAPI_BUFFER: u32 = 4;
pub const BASS_WASAPI_EVENT: u32 = 16;
pub const BASS_WASAPI_SAMPLES: u32 = 32;
pub const BASS_WASAPI_DITHER: u32 = 64;
pub const BASS_WASAPI_RAW: u32 = 128;
pub const BASS_WASAPI_ASYNC: u32 = 0x100;

pub const BASS_SYNC_POS: u32 = 0;
pub const BASS_SYNC_END: u32 = 2;
pub const BASS_SYNC_META: u32 = 4;
pub const BASS_SYNC_SLIDE: u32 = 5;
pub const BASS_SYNC_STALL: u32 = 6;
pub const BASS_SYNC_DOWNLOAD: u32 = 7;
pub const BASS_SYNC_FREE: u32 = 8;
pub const BASS_SYNC_SETPOS: u32 = 11;
pub const BASS_SYNC_MUSICPOS: u32 = 10;
pub const BASS_SYNC_MUSICINST: u32 = 125;
pub const BASS_SYNC_MUSICFX: u32 = 3;
pub const BASS_SYNC_OGG_CHANGE: u32 = 12;
pub const BASS_SYNC_DEV_FAIL: u32 = 14;
pub const BASS_SYNC_DEV_FORMAT: u32 = 15;
pub const BASS_SYNC_THREAD: u32 = 0x20000000; // flag: call sync in other thread
pub const BASS_SYNC_MIXTIME: u32 = 0x40000000; // flag: sync at mixtime, else at playtime
pub const BASS_SYNC_ONETIME: u32 = 0x80000000; // flag: sync only once, else continuously

pub const BASS_FX_DX8_PARAMEQ			:u32=7;

pub const  BASS_DATA_FFT512	 :u32= 0x80000001;	// 512 FFT
pub const  BASS_DATA_FFT1024 :u32=	0x80000002;	// 1024 FFT
pub const  BASS_DATA_FFT2048 :u32=	0x80000003;	// 2048 FFT