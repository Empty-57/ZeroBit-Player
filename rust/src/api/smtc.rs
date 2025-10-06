use crate::frb_generated::StreamSink;
use once_cell::sync::Lazy;
use std::sync::Mutex;
use windows::core::{HSTRING};
use windows::Foundation::TypedEventHandler;
use windows::Media::Playback::MediaPlayer;
use windows::Media::{
    MediaPlaybackStatus, MediaPlaybackType, SystemMediaTransportControls,
    SystemMediaTransportControlsButton, SystemMediaTransportControlsButtonPressedEventArgs,
};
use windows::Storage::Streams::{
    DataWriter, InMemoryRandomAccessStream, RandomAccessStreamReference,
};

static SMTC: Lazy<Mutex<Option<SystemMediaTransportControls>>> = Lazy::new(|| Mutex::new(None));

#[flutter_rust_bridge::frb]
pub fn init_smtc() -> Result<(), String> {
    let player = MediaPlayer::new().map_err(|e| e.to_string())?;

    player
        .CommandManager()
        .map_err(|e| e.to_string())?
        .SetIsEnabled(false)
        .map_err(|e| e.to_string())?;

    *SMTC.lock().unwrap() = Some(
        player
            .SystemMediaTransportControls()
            .map_err(|e| e.to_string())?,
    );

    SMTC.lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .SetIsNextEnabled(true)
        .map_err(|e| e.to_string())?;
    SMTC.lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .SetIsPauseEnabled(true)
        .map_err(|e| e.to_string())?;
    SMTC.lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .SetIsPlayEnabled(true)
        .map_err(|e| e.to_string())?;
    SMTC.lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .SetIsPreviousEnabled(true)
        .map_err(|e| e.to_string())?;

    Ok(())
}

#[flutter_rust_bridge::frb]
pub enum SMTCControlEvent {
    Play,
    Pause,
    Previous,
    Next,
    Unknown,
}

#[flutter_rust_bridge::frb]
pub enum SMTCState {
    Paused,
    Playing,
}

// enum AudioState { stop, playing, pause }
#[flutter_rust_bridge::frb]
pub fn smtc_update_state(state: SMTCState) -> Result<(), String> {
    let state = match state {
        SMTCState::Playing => MediaPlaybackStatus::Playing,
        SMTCState::Paused => MediaPlaybackStatus::Paused,
    };
    SMTC.lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .SetPlaybackStatus(state)
        .map_err(|e| e.to_string())?;
    SMTC.lock().unwrap().as_ref().unwrap().DisplayUpdater().map_err(|e|e.to_string())?.Update().map_err(|e|e.to_string()).unwrap_or(());
    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn smtc_update_metadata(
    title: String,
    artist: String,
    album: String,
    cover_src: Vec<u8>,
) -> Result<(), windows::core::Error> {
    let updater = SMTC.lock().unwrap().as_ref().unwrap().DisplayUpdater()?;

    updater.SetType(MediaPlaybackType::Music)?;

    let audio_properties = updater.MusicProperties()?;
    audio_properties.SetTitle(&HSTRING::from(title))?;
    audio_properties.SetArtist(&HSTRING::from(artist))?;
    audio_properties.SetAlbumTitle(&HSTRING::from(album))?;

    let data_writer = DataWriter::new()?;
    data_writer.WriteBytes(&cover_src)?;
    let ibuffer = data_writer.DetachBuffer()?;

    let stream = {
        let s = InMemoryRandomAccessStream::new()?;
        s.WriteAsync(&ibuffer)?.get()?;
        s.FlushAsync()?.get()?;
        s
    };

    updater.SetThumbnail(&RandomAccessStreamReference::CreateFromStream(&stream)?)?;
    updater.Update()?;

    if !SMTC.lock().unwrap().as_ref().unwrap().IsEnabled()? {
        SMTC.lock().unwrap().as_ref().unwrap().SetIsEnabled(true)?;
    }
    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn smtc_control_events(sink: StreamSink<SMTCControlEvent>) {
    SMTC.lock()
        .unwrap()
        .as_ref()
        .unwrap()
        .ButtonPressed(&TypedEventHandler::<
            SystemMediaTransportControls,
            SystemMediaTransportControlsButtonPressedEventArgs,
        >::new(move |_, event| {
            let event = match event.as_ref().unwrap().Button().unwrap() {
                SystemMediaTransportControlsButton::Play => SMTCControlEvent::Play,
                SystemMediaTransportControlsButton::Pause => SMTCControlEvent::Pause,
                SystemMediaTransportControlsButton::Next => SMTCControlEvent::Next,
                SystemMediaTransportControlsButton::Previous => SMTCControlEvent::Previous,
                _=> SMTCControlEvent::Unknown,
            };
            sink.add(event).unwrap_or_else(|e| {
            eprintln!("SMTC Event ERR: {:?}", e);
        });
            Ok(())
        }))
        .unwrap();
}

#[flutter_rust_bridge::frb]
pub fn smtc_clear(){
    let updater = SMTC.lock().unwrap().as_ref().unwrap().DisplayUpdater().unwrap();
    updater.ClearAll().unwrap();
    updater.Update().unwrap();
    SMTC.lock().unwrap().as_ref().unwrap().SetIsEnabled(false).unwrap();
}

