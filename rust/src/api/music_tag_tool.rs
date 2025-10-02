use image::{load_from_memory, ImageFormat};
use lofty::config::{ParseOptions, WriteOptions};
use lofty::error::{ErrorKind as LoftyErrorKind, LoftyError};
use lofty::file::{TaggedFile, TaggedFileExt};
use lofty::picture::{MimeType, Picture, PictureType};
use lofty::prelude::{Accessor, AudioFile, ItemKey, TagExt};
use lofty::probe::Probe;
use lofty::tag::{Tag, TagItem};
use std::borrow::Cow;
use std::fs;
use std::io::Cursor;
use std::io::ErrorKind as IoErrorKind;
use std::path::Path;
use std::time::Duration;
use lofty::read_from_path;
use windows::core::HSTRING;
use windows::Storage::StorageFile;

fn get_duration_with_win(path: impl AsRef<Path>) -> Result<f32, windows::core::Error> {
    let path_str = path.as_ref().to_str().unwrap_or("");
    let hstring_path = HSTRING::from(path_str);
    
    let storage_file = StorageFile::GetFileFromPathAsync(&hstring_path)?.get()?;
    
    let music_properties = storage_file
        .Properties()?
        .GetMusicPropertiesAsync()?
        .get()?;
    
    let duration : Duration = music_properties.Duration()?.into();
    let duration:f32  =duration.as_secs_f32();

    Ok(duration)
}

pub struct EditableMetadata {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub genre: Option<String>,
}

pub struct AudioMetadata {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub genre: String,
    pub duration: f32,
    pub bitrate: Option<u32>,
    pub sample_rate: Option<u32>,
    pub path: String,
}

fn handle_get_eof_error(
    err: LoftyError,
    path: &Path,
    options: ParseOptions,
) -> Option<TaggedFile> {
    match err.kind() {
        LoftyErrorKind::Io(inner) if inner.kind() == IoErrorKind::UnexpectedEof => {
            Probe::open(path).ok()?.options(options).read().ok()
        }
        _ => {
            println!("Error Get Cover: {:?}", err.kind());
            None
        }
    }
}

impl AudioMetadata {
    fn new(path: String) -> Self {
        let path_ = Path::new(&path);
        AudioMetadata {
            title: path_
                .file_name()
                .unwrap_or("UNKNOWN".as_ref())
                .to_string_lossy()
                .to_string(),
            artist: "UNKNOWN".to_string(),
            album: "UNKNOWN".to_string(),
            genre: "UNKNOWN".to_string(),
            duration: 0.0,
            bitrate: Some(0),
            sample_rate: Some(0),
            path: path_.to_string_lossy().to_string(),
        }
    }

    fn get_tag(path: &String, err_msg: &str) -> Option<Tag> {
        let path_ = Path::new(&path);

        let metadata = fs::metadata(path).expect("Unable to get file metadata");
        let mut permissions = metadata.permissions();

        //检查文件是否为只读
        if permissions.readonly() {
            #[allow(clippy::permissions_set_readonly_false)]
            permissions.set_readonly(false);
            fs::set_permissions(path, permissions).expect("File permissions cannot be modified");
        }

        let mut tagged_file = match read_from_path(path_) {
            Ok(v) => v,
            Err(err) => {
                println!("{}: {:?}", err_msg, err.kind());
                return None;
            }
        };

        let tag: Tag = if let Some(primary) = tagged_file.primary_tag() {
            primary.clone()
        } else if let Some(first) = tagged_file.first_tag() {
            first.clone()
        } else {
            let ttype = tagged_file.primary_tag_type();
            eprintln!(
                "WARN: no tags found, creating a new one of type {:?}",
                ttype
            );
            tagged_file.insert_tag(Tag::new(ttype));
            tagged_file.primary_tag().unwrap().clone()
        };
        Some(tag)
    }

    fn render_tags(path: String) -> Self {
        let path_ = Path::new(&path);
        let tagged_file = match Probe::open(path_) {
            Ok(v) => match v
                .options(
                    ParseOptions::new()
                        .read_cover_art(false)
                        .read_properties(true)
                        .read_tags(true),
                )
                .read()
            {
                Ok(f) => f,
                Err(err) => {
                    println!("Error reading file: {:?}", err.kind());
                    return Self::new(path);
                }
            },
            Err(err) => {
                println!("Error reading TaggedFile: {:?}", err.kind());
                return Self::new(path);
            }
        };

        let properties = tagged_file.properties();
        
        let primary_duration = properties.duration();
        
        let duration: f32 = if primary_duration == Duration::ZERO { 
            get_duration_with_win(path_).unwrap_or(0.0) 
        } else { 
            primary_duration.as_secs_f32()
        };

        if let Some(tag) = tagged_file
            .primary_tag()
            .or_else(|| tagged_file.first_tag())
        {
            let artist_strs: Vec<_> = tag.get_strings(&ItemKey::TrackArtist).collect();
            let artist = if artist_strs.is_empty() {
                Cow::Borrowed("UNKNOWN").to_string()
            } else {
                artist_strs.join("/")
            };

            return AudioMetadata {
                title: tag
                    .title()
                    .unwrap_or(
                        path_
                            .file_stem()
                            .unwrap_or("UNKNOWN".as_ref())
                            .to_string_lossy(),
                    )
                    .to_string(),
                artist,
                album: tag.album().unwrap_or(Cow::Borrowed("UNKNOWN")).to_string(),
                genre: tag.genre().unwrap_or(Cow::Borrowed("UNKNOWN")).to_string(),
                duration,
                bitrate: properties.audio_bitrate(),
                sample_rate: properties.sample_rate(),
                path: path_.to_string_lossy().to_string(),
            };
        }

        AudioMetadata {
            title: path_
                .file_stem()
                .unwrap_or("UNKNOWN".as_ref())
                .to_string_lossy()
                .to_string(),
            artist: "UNKNOWN".to_string(),
            album: "UNKNOWN".to_string(),
            genre: "UNKNOWN".to_string(),
            duration,
            bitrate: properties.audio_bitrate(),
            sample_rate: properties.sample_rate(),
            path: path_.to_string_lossy().to_string(),
        }
    }

    fn get_cover(path: String) -> Option<Vec<u8>> {
        let path_ = Path::new(&path);

        let options = ParseOptions::new()
            .read_cover_art(true)
            .read_properties(false)
            .read_tags(true);
        let tagged_file = match Probe::open(path_) {
            Ok(v) => match v.options(options).read() {
                Ok(f) => f,
                Err(err) => handle_get_eof_error(err, path_, options)?,
            },
            Err(err) => handle_get_eof_error(err, path_, options)?,
        };
        if let Some(tag) = tagged_file
            .primary_tag()
            .or_else(|| tagged_file.first_tag())
        {
            if let Some(pic) = tag.pictures().first() {
                return Some(Vec::from(pic.data()));
            };
        }
        None
    }

    fn edit_tags(path: String, data: EditableMetadata) {
        if let Some(mut tag) = Self::get_tag(&path, "Error Edit Tags") {
            if let Some(title) = data.title {
                tag.set_title(title);
            }
            if let Some(artist) = data.artist {
                tag.set_artist(artist);
            }
            if let Some(album) = data.album {
                tag.set_album(album);
            }
            if let Some(genre) = data.genre {
                tag.set_genre(genre);
            }
            tag.save_to_path(path, WriteOptions::default()).unwrap_or_else(|e|println!("ERROR: Save Metadata ERR! | {:?}",e));
        }
    }

    fn edit_cover(path: String, src: Vec<u8>) {
        if let Some(mut tag) = Self::get_tag(&path, "Error Edit Cover") {
            let image_data = match load_from_memory(src.as_slice()) {
                Ok(v) => v,
                Err(err) => {
                    println!("Error Edit cover: {}", err);
                    return;
                }
            };

            let image_data = image_data.resize(800, 800, image::imageops::FilterType::Lanczos3);

            let mut output_bytes = Vec::new();
            image_data
                .write_to(&mut Cursor::new(&mut output_bytes), ImageFormat::Png)
                .unwrap_or_else(|err| {
                    println!("Error resize cover: {}", err);
                });

            tag.set_picture(
                0,
                Picture::new_unchecked(
                    PictureType::CoverFront,
                    Some(MimeType::Png),
                    None,
                    output_bytes,
                ),
            );
            tag.save_to_path(path, WriteOptions::default()).unwrap_or_else(|e|println!("ERROR: Save Cover ERR! | {:?}",e));
        }
    }

    fn get_embedded_lyric(path: String) -> Option<String> {
        let path_ = Path::new(&path);
        let tagged_file = match Probe::open(path_) {
            Ok(v) => match v
                .options(
                    ParseOptions::new()
                        .read_cover_art(false)
                        .read_properties(false)
                        .read_tags(true),
                )
                .read()
            {
                Ok(f) => f,
                Err(err) => {
                    println!("Error reading file: {:?}", err.kind());
                    return None;
                }
            },
            Err(err) => {
                println!("Error reading TaggedFile: {:?}", err.kind());
                return None;
            }
        };

        if let Some(tag) = tagged_file
            .primary_tag()
            .or_else(|| tagged_file.first_tag())
        {
            let lyric_items= tag.get_items(&ItemKey::Lyrics).collect::<Vec<&TagItem>>();
            for item in lyric_items {
                if let Some(lyric) = item.value().text(){
                    return Some(lyric.to_string());
                }
            }
        }
        None
    }
    
    fn edit_embedded_lyric(path: String, lyric: String){
        if let Some(mut tag) = Self::get_tag(&path, "Error Edit Lyric") {
            tag.insert_text(ItemKey::Lyrics,lyric);
            tag.save_to_path(path, WriteOptions::default()).unwrap_or_else(|e|println!("ERROR: Save Lyrics ERR! | {:?}",e));
        }
    }
    
}

#[flutter_rust_bridge::frb]
pub fn get_metadata(path: String) -> AudioMetadata {
    AudioMetadata::render_tags(path)
}

#[flutter_rust_bridge::frb]
pub fn get_cover(path: String, size_flag: u8) -> Option<Vec<u8>> {
    if let Some(image_data) = AudioMetadata::get_cover(path) {
        let image_data = match load_from_memory(image_data.as_slice()) {
            Ok(v) => v,
            Err(err) => {
                println!("Error get cover: {}", err);
                return None;
            }
        };
        let mut cover_size = (150, 150);

        match size_flag {
            0 => cover_size = (150, 150),
            1 => cover_size = (800, 800),
            _ => {}
        };

        let (cover_witdh, cover_height) = cover_size;

        let image_data = image_data.resize(
            cover_witdh,
            cover_height,
            image::imageops::FilterType::Lanczos3,
        );

        let mut output_bytes = Vec::new();
        image_data
            .write_to(&mut Cursor::new(&mut output_bytes), ImageFormat::Png)
            .unwrap_or_else(|err| {
                println!("Error resize cover: {}", err);
            });

        return Some(output_bytes);
    }
    None
}

#[flutter_rust_bridge::frb]
pub fn edit_tags(path: String, data: EditableMetadata) {
    AudioMetadata::edit_tags(path, data)
}

#[flutter_rust_bridge::frb]
pub fn edit_cover(path: String, src: Vec<u8>) {
    AudioMetadata::edit_cover(path, src)
}

#[flutter_rust_bridge::frb]
pub fn get_embedded_lyric(path: String) -> Option<String> { AudioMetadata::get_embedded_lyric(path) }

#[flutter_rust_bridge::frb]
pub fn edit_embedded_lyric(path: String, lyric: String) {AudioMetadata::edit_embedded_lyric(path, lyric)}
