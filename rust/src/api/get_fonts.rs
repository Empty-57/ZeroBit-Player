use std::fs;
use std::path::PathBuf;
use ttf_parser::{name_id, Face};

fn get_all_font_names() -> Result<Vec<String>, String> {
    let system_fonts = PathBuf::from(r"C:\Windows\Fonts");
    let user_fonts = dirs::data_local_dir()
        .map(|p| p.join(r"Microsoft\Windows\Fonts"))
        .unwrap_or_default();

    let font_dirs = vec![system_fonts, user_fonts];

    let mut font_names: Vec<String> = Vec::new();

    for dir in font_dirs {
        if !dir.exists() || !dir.is_dir() {
            continue;
        }
        let entries = fs::read_dir(&dir).map_err(|e| e.to_string())?;

        for entry in entries.flatten() {
            let path = entry.path();
            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");

            if !matches!(ext.to_ascii_lowercase().as_str(), "ttf" | "ttc" | "otf") {
                continue;
            }
            let data = fs::read(&path).map_err(|e| e.to_string())?;

            if let Ok(face) = Face::parse(&data, 0) {
                for name in face.names() {
                    if name.name_id != name_id::FULL_NAME {
                        continue;
                    }
                    match name.to_string() {
                        Some(value) => {
                            font_names.push(value);
                            break;
                        }
                        None => continue,
                    };
                }
            }
        }
    }
    font_names.sort();
    font_names.dedup();

    Ok(font_names)
}

#[flutter_rust_bridge::frb]
pub fn get_fonts_list() -> Result<Vec<String>, String> {
    get_all_font_names()
}
