//! Module containing the actual Surfer plugin API.

use compile_time::datetime_str;

use extism_pdk::host_fn;
use extism_pdk::{FnResult, Json, plugin_fn};
use extism_pdk::{error, info, warn};

use surfer_translation_types::WaveSource;
pub use surfer_translation_types::plugin_types::TranslateParams;
use surfer_translation_types::{
    TranslationPreference, TranslationResult, VariableInfo, VariableMeta as VMeta, VariableValue,
};

use lazy_static::lazy_static;
use std::sync::Mutex;

use toml::Table;

use camino::Utf8PathBuf;

use crate::config::*;
use crate::data::*;
use crate::state::*;

type VariableMeta = VMeta<(), ()>;

/// Get the name of a signal as a period separated string (i.e. `logic.module.signal`).
fn signal_name(signal: &VariableMeta) -> String {
    signal
        .var
        .path
        .strs
        .iter()
        .map(|s| s.to_owned() + ".")
        .collect::<Vec<_>>()
        .join("")
        + &signal.var.name
}

lazy_static! {
    /// The global state of the translator.
    pub static ref STATE: Mutex<State> = Mutex::new(State::new());
}

#[plugin_fn]
pub fn new() -> FnResult<()> {
    info!("SHOCKWAVES: Created plugin");

    let dir = unsafe { translators_config_dir(()) };
    if let Ok(Json(Some(dir))) = dir {
        let dir = Utf8PathBuf::from(&dir);
        info!("SHOCKWAVES: Config dir: {dir:?}");

        let mut file = dir.clone();
        file.push("shockwaves/config.toml");
        let file = file.into_string();

        info!("SHOCKWAVES: Looking for global config file: {file}");
        if let Some(c) = read_conf_file(file) {
            STATE.lock().unwrap().config.set_global_conf(c);
        }

        STATE.lock().unwrap().config.conf_dir = Some(dir);
    } else {
        info!("SHOCKWAVES: No config directory detected");
    }
    STATE.lock().unwrap().config.conf_dir = None;
    Ok(())
}

#[plugin_fn]
pub fn name() -> FnResult<String> {
    let version = include_str!("../VERSION");

    Ok("Shockwaves ".to_string()
        + if version.is_empty() {
            datetime_str!()
        } else {
            version
        })
}

#[plugin_fn]
pub fn translates(variable: VariableMeta) -> FnResult<TranslationPreference> {
    let signal = signal_name(&variable);
    Ok(if STATE.lock().unwrap().data.can_translate(&signal) {
        TranslationPreference::Prefer
    } else {
        TranslationPreference::No
    })
}

#[plugin_fn]
pub fn variable_info(variable: VariableMeta) -> FnResult<VariableInfo> {
    let signal = signal_name(&variable);
    Ok(STATE.lock().unwrap().structure(&signal))
}

#[plugin_fn]
pub fn translate(
    TranslateParams { variable, value }: TranslateParams,
) -> FnResult<TranslationResult> {
    let val_raw = match value {
        VariableValue::BigUint(v) => format!(
            "{v:0width$b}",
            width = &(variable.num_bits.unwrap_or(0) as usize)
        ),
        VariableValue::String(v) => v.clone(),
    };
    let signal = signal_name(&variable);
    Ok(STATE.lock().unwrap().translate(&signal, val_raw.as_str()))
}

#[plugin_fn]
pub fn set_wave_source(Json(wave_source): Json<Option<WaveSource>>) -> FnResult<()> {
    info!("SHOCKWAVES: Loading source {wave_source:?}");

    let source_file = wave_source
        .and_then(|ws| match ws {
            WaveSource::File(f) => Some(f),
            WaveSource::Data => None,
            WaveSource::DragAndDrop(f) => f,
            WaveSource::Url(_) => None,
            WaveSource::Cxxrtl => None,
        })
        .map(|ws| ws.replace("\\", "/"));

    let (data, conf, wavesource_dir) = if let Some(source_file) = source_file {
        // If there is a proper file path, try to find the metadata file locally,
        // as well as a local config file.

        // META:
        let mut metafile = Utf8PathBuf::from(&source_file);
        metafile.set_extension("json");
        let metafile = metafile.into_string();

        info!("SHOCKWAVES: Looking for metadata file {metafile}");
        let data = read_meta_file(metafile);

        // CONF:
        let mut ws_dir = Utf8PathBuf::from(&source_file);
        ws_dir.pop();
        let mut conf_file = ws_dir.clone();
        conf_file.push("shockwaves.toml");
        let conf_file = conf_file.into_string();

        info!("SHOCKWAVES: Looking for local config file {conf_file}");
        let conf = read_conf_file(conf_file);

        (data, conf, Some(ws_dir))
    } else {
        info!("SHOCKWAVES: No suitable waveform source");
        (None, None, None)
    };

    let mut state = STATE.lock().unwrap();
    state.config.wavesource_dir = wavesource_dir;
    state
        .config
        .set_local_conf(conf.unwrap_or_else(Configuration::default));
    state.set_data(data.unwrap_or_else(Data::new));
    state.replace_wavestyles();

    Ok(())
}

/// Read a file (i.e. for configuration).
fn try_read_file(file: String) -> Option<Vec<u8>> {
    if let Ok(true) = unsafe { file_exists(file.clone()) } {
        let bytes = unsafe { read_file(file.clone()) };
        match bytes {
            Ok(bytes) => Some(bytes),
            Err(e) => {
                error!("SHOCKWAVES: Could not read file: {e}");
                None
            }
        }
    } else {
        warn!("SHOCKWAVES: File not found");
        None
    }
}

/// Read and parse a configuration file.
fn read_conf_file(file: String) -> Option<Configuration> {
    try_read_file(file).and_then(|bytes| match toml::from_slice(&bytes) {
        Ok(conf) => {
            info!("SHOCKWAVES: Parsed config file");
            Some(conf)
        }
        Err(e) => {
            error!("SHOCKWAVES: Could not config file: {e}");
            None
        }
    })
}

/// Read and parse the metadata JSON file.
pub fn read_meta_file(file: String) -> Option<Data> {
    try_read_file(file).and_then(|bytes| match serde_json::from_slice(&bytes) {
        Ok(data) => {
            info!("SHOCKWAVES: Parsed metadata file");
            Some(data)
        }
        Err(e) => {
            error!("SHOCKWAVES: Could not parse metadata file: {e}");
            None
        }
    })
}

/// Read and parse a style variables configuration file.
pub fn read_style_file(file: String) -> Option<Table> {
    try_read_file(file).and_then(|bytes| match toml::from_slice::<Table>(&bytes) {
        Ok(style) => {
            info!("SHOCKWAVES: Parsed metadata file");
            Some(style)
        }
        Err(e) => {
            error!("SHOCKWAVES: Could not parse metadata file: {e}");
            None
        }
    })
}

#[host_fn]
extern "ExtismHost" {
    pub fn read_file(filename: String) -> Vec<u8>;
    pub fn file_exists(filename: String) -> bool;
    pub fn translators_config_dir(_user_data: ()) -> Json<Option<String>>;
}
