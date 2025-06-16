// BASS_ERROR_MEM		1	// memory error
// BASS_ERROR_FILEOPEN	2	// can't open the file
// BASS_ERROR_DRIVER	3	// can't find a free/valid driver
// BASS_ERROR_BUFLOST	4	// the sample buffer was lost
// BASS_ERROR_HANDLE	5	// invalid handle
// BASS_ERROR_FORMAT	6	// unsupported sample format
// BASS_ERROR_POSITION	7	// invalid position
// BASS_ERROR_INIT		8	// BASS_Init has not been successfully called
// BASS_ERROR_START	9	// BASS_Start has not been successfully calle
// BASS_ERROR_SSL		10	// SSL/HTTPS support isn't available
// BASS_ERROR_REINIT	11	// device needs to be reinitialized
// BASS_ERROR_ALREADY	14	// already initialized/paused/whatever
// BASS_ERROR_NOTAUDIO	17	// file does not contain audio
// BASS_ERROR_NOCHAN	18	// can't get a free channel
// BASS_ERROR_ILLTYPE	19	// an illegal type was specified
// BASS_ERROR_ILLPARAM	20	// an illegal parameter was specified
// BASS_ERROR_NO3D		21	// no 3D support
// BASS_ERROR_NOEAX	22	// no EAX support
// BASS_ERROR_DEVICE	23	// illegal device number
// BASS_ERROR_NOPLAY	24	// not playing
// BASS_ERROR_FREQ		25	// illegal sample rate
// BASS_ERROR_NOTFILE	27	// the stream is not a file stream
// BASS_ERROR_NOHW		29	// no hardware voices available
// BASS_ERROR_EMPTY	31	// the file has no sample data
// BASS_ERROR_NONET	32	// no internet connection could be opened
// BASS_ERROR_CREATE	33	// couldn't create the file
// BASS_ERROR_NOFX		34	// effects are not available
// BASS_ERROR_NOTAVAIL	37	// requested data/action is not available
// BASS_ERROR_DECODE	38	// the channel is/isn't a "decoding channel"
// BASS_ERROR_DX		39	// a sufficient DirectX version is not instal
// BASS_ERROR_TIMEOUT	40	// connection timedout
// BASS_ERROR_FILEFORM	41	// unsupported file format
// BASS_ERROR_SPEAKER	42	// unavailable speaker
// BASS_ERROR_VERSION	43	// invalid BASS version (used by add-ons)
// BASS_ERROR_CODEC	44	// codec is not available/supported
// BASS_ERROR_ENDED	45	// the channel/file has ended
// BASS_ERROR_BUSY		46	// the device is busy
// BASS_ERROR_UNSTREAMABLE	47	// unstreamable file
// BASS_ERROR_PROTOCOL	48	// unsupported protocol
// BASS_ERROR_DENIED	49	// access denied
// BASS_ERROR_UNKNOWN	-1	// some other mystery problem

pub(crate) fn get_err_info(err_code: i32) -> Option<String> {
    match err_code {
        1  => Some(format!("BASS_ERROR_MEM<memory error> | ERR_CODE<{}>", err_code)),
        2  => Some(format!("BASS_ERROR_FILEOPEN<can't open the file> | ERR_CODE<{}>", err_code)),
        3  => Some(format!("BASS_ERROR_DRIVER<can't find a free/valid driver> | ERR_CODE<{}>", err_code)),
        4  => Some(format!("BASS_ERROR_BUFLOST<the sample buffer was lost> | ERR_CODE<{}>", err_code)),
        5  => Some(format!("BASS_ERROR_HANDLE<invalid handle> | ERR_CODE<{}>", err_code)),
        6  => Some(format!("BASS_ERROR_FORMAT<unsupported sample format> | ERR_CODE<{}>", err_code)),
        7  => Some(format!("BASS_ERROR_POSITION<invalid position> | ERR_CODE<{}>", err_code)),
        8  => Some(format!("BASS_ERROR_INIT<BASS_Init has not been successfully called> | ERR_CODE<{}>", err_code)),
        9  => Some(format!("BASS_ERROR_START<BASS_Start has not been successfully called> | ERR_CODE<{}>", err_code)),
        10 => Some(format!("BASS_ERROR_SSL<SSL/HTTPS support isn't available> | ERR_CODE<{}>", err_code)),
        11 => Some(format!("BASS_ERROR_REINIT<device needs to be reinitialized> | ERR_CODE<{}>", err_code)),
        14 => Some(format!("BASS_ERROR_ALREADY<already initialized/paused/whatever> | ERR_CODE<{}>", err_code)),
        17 => Some(format!("BASS_ERROR_NOTAUDIO<file does not contain audio> | ERR_CODE<{}>", err_code)),
        18 => Some(format!("BASS_ERROR_NOCHAN<can't get a free channel> | ERR_CODE<{}>", err_code)),
        19 => Some(format!("BASS_ERROR_ILLTYPE<an illegal type was specified> | ERR_CODE<{}>", err_code)),
        20 => Some(format!("BASS_ERROR_ILLPARAM<an illegal parameter was specified> | ERR_CODE<{}>", err_code)),
        21 => Some(format!("BASS_ERROR_NO3D<no 3D support> | ERR_CODE<{}>", err_code)),
        22 => Some(format!("BASS_ERROR_NOEAX<no EAX support> | ERR_CODE<{}>", err_code)),
        23 => Some(format!("BASS_ERROR_DEVICE<illegal device number> | ERR_CODE<{}>", err_code)),
        24 => Some(format!("BASS_ERROR_NOPLAY<not playing> | ERR_CODE<{}>", err_code)),
        25 => Some(format!("BASS_ERROR_FREQ<illegal sample rate> | ERR_CODE<{}>", err_code)),
        27 => Some(format!("BASS_ERROR_NOTFILE<the stream is not a file stream> | ERR_CODE<{}>", err_code)),
        29 => Some(format!("BASS_ERROR_NOHW<no hardware voices available> | ERR_CODE<{}>", err_code)),
        31 => Some(format!("BASS_ERROR_EMPTY<the file has no sample data> | ERR_CODE<{}>", err_code)),
        32 => Some(format!("BASS_ERROR_NONET<no internet connection could be opened> | ERR_CODE<{}>", err_code)),
        33 => Some(format!("BASS_ERROR_CREATE<couldn't create the file> | ERR_CODE<{}>", err_code)),
        34 => Some(format!("BASS_ERROR_NOFX<effects are not available> | ERR_CODE<{}>", err_code)),
        37 => Some(format!("BASS_ERROR_NOTAVAIL<requested data/action is not available> | ERR_CODE<{}>", err_code)),
        38 => Some(format!("BASS_ERROR_DECODE<the channel is/isn't a \"decoding channel\"> | ERR_CODE<{}>", err_code)),
        39 => Some(format!("BASS_ERROR_DX<a sufficient DirectX version is not installed> | ERR_CODE<{}>", err_code)),
        40 => Some(format!("BASS_ERROR_TIMEOUT<connection timed out> | ERR_CODE<{}>", err_code)),
        41 => Some(format!("BASS_ERROR_FILEFORM<unsupported file format> | ERR_CODE<{}>", err_code)),
        42 => Some(format!("BASS_ERROR_SPEAKER<unavailable speaker> | ERR_CODE<{}>", err_code)),
        43 => Some(format!("BASS_ERROR_VERSION<invalid BASS version (used by add-ons)> | ERR_CODE<{}>", err_code)),
        44 => Some(format!("BASS_ERROR_CODEC<codec is not available/supported> | ERR_CODE<{}>", err_code)),
        45 => Some(format!("BASS_ERROR_ENDED<the channel/file has ended> | ERR_CODE<{}>", err_code)),
        46 => Some(format!("BASS_ERROR_BUSY<the device is busy> | ERR_CODE<{}>", err_code)),
        47 => Some(format!("BASS_ERROR_UNSTREAMABLE<unstreamable file> | ERR_CODE<{}>", err_code)),
        48 => Some(format!("BASS_ERROR_PROTOCOL<unsupported protocol> | ERR_CODE<{}>", err_code)),
        49 => Some(format!("BASS_ERROR_DENIED<access denied> | ERR_CODE<{}>", err_code)),
       -1 => Some(format!("BASS_ERROR_UNKNOWN<some other mystery problem> | ERR_CODE<{}>", err_code)),
        _  => None,
    }
}
