//! Module for handling configuration options.
//!
//! There is one `Config` object that keeps score of all configurations.
//! The system looks for a global and local config file, which get parsed into
//! `Configuration` objects.

use either::Either;
use either::Either::*;
use extism_pdk::{error, info, warn};

use serde::{Deserialize, Serialize};
use toml::{Table, Value as TVal};

use camino::Utf8PathBuf;
use egui::Color32;
use std::collections::HashMap;

use crate::data::*;
use crate::plugin::*;

/// The main configuration object, which includes local and global configurations,
/// the directories for style files, and the combined style variable map.
#[derive(Debug, Default)]
pub struct Config {
    pub global: Configuration,
    pub local: Configuration,

    pub conf_dir: Option<Utf8PathBuf>,
    pub wavesource_dir: Option<Utf8PathBuf>,

    pub style: StyleMap,
}

type StyleMap = HashMap<String, Either<Option<WaveStyle>, toml::Value>>;

/// A single configuration file
#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Configuration {
    #[serde(default)]
    pub propagate_errors: Option<bool>,

    #[serde(default)]
    pub override_sig_spacer: Option<NumberSpacer>,
    #[serde(default)]
    pub override_uns_spacer: Option<NumberSpacer>,
    #[serde(default)]
    pub override_hex_spacer: Option<NumberSpacer>,
    #[serde(default)]
    pub override_oct_spacer: Option<NumberSpacer>,
    #[serde(default)]
    pub override_bin_spacer: Option<NumberSpacer>,

    #[serde(default)]
    pub styles: Vec<String>,
    #[serde(default)]
    pub style: Option<Table>,
}

impl Config {
    /// Set the global configuration options.
    pub fn set_global_conf(&mut self, conf: Configuration) {
        self.global = conf;
        self.read_styles();
    }
    /// Set the local configuration options.
    pub fn set_local_conf(&mut self, conf: Configuration) {
        self.local = conf;
        self.read_styles();
    }

    fn read_styles(&mut self) {
        info!("SHOCKWAVES: Reapplying styles");
        self.style.clear();
        // apply style variables directly specified in the config file first
        if let Some(s) = self.global.style.clone() {
            self.apply_styles(s);
        }
        // and only THEN read the files listed
        for sfile in self.global.styles.clone() {
            self.read_style(sfile);
        }
        // then do the same for local files
        if let Some(s) = self.local.style.clone() {
            self.apply_styles(s);
        }
        for sfile in self.local.styles.clone() {
            self.read_style(sfile);
        }
    }

    fn read_style(&mut self, sfile: String) {
        let mut path = Utf8PathBuf::from(sfile.replace("\\", "/"));
        if path.extension().is_none() {
            path.set_extension("toml");
        }

        let file = if path.starts_with("./") {
            // Use local file
            self.wavesource_dir
                .as_ref()
                .map(|dir| dir.join(&path).into_string())
        } else if path.is_absolute() || path.to_string().chars().nth(1) == Some(':') {
            // C-style disk (HACK!)
            // -> use absolute path
            Some(path.to_string())
        } else {
            //use path relative to config dir
            self.conf_dir
                .as_ref()
                .map(|dir| dir.join("shockwaves/styles").join(&path).into_string())
        };

        if let Some(file) = file {
            info!("Looking for style file {file}");
            if let Some(styles) = read_style_file(file) {
                self.apply_styles(styles);
            }
        } else {
            warn!("Could not find path for for {path:?}");
        }
    }

    /// Update the style table with the styles from a style config table.
    fn apply_styles(&mut self, styles: Table) {
        for (key, value) in styles.into_iter() {
            self.style.insert(key, Right(value)); //Right means "not yet evaluated"
        }
    }

    /// Parse a wavestyle in the context of the style variables table.
    pub fn get_style(&mut self, ws: &WaveStyle) -> WaveStyle {
        match ws {
            WaveStyle::Var(v, def) => self.get_style_var(v).unwrap_or_else(|| self.get_style(def)),
            ws => ws.clone(),
        }
    }

    /// Evaluate a style variable. Styles are evaluated lazily, i.e. when they first
    /// get used.
    fn get_style_var(&mut self, var: &str) -> Option<WaveStyle> {
        match self.style.get(var) {
            Some(Left(ws)) => ws.clone(),
            Some(Right(val)) => {
                let ws = self.get_style_toml(val.clone());
                self.style.insert(var.to_string(), Left(ws.clone()));
                ws
            }
            None => {
                error!("SHOCKWAVES: Unknown style var {var}");
                None
            }
        }
    }

    /// Parse a TOML value in a config file into a wavestyle.
    fn get_style_toml(&mut self, val: TVal) -> Option<WaveStyle> {
        match val {
            TVal::String(s) => self.get_style_string(&s),
            TVal::Array(a) => a.into_iter().filter_map(|v| self.get_style_toml(v)).next(),
            v => {
                error!("SHOCKWAVES: Could not parse value {v:?}");
                None
            }
        }
    }

    /// Get a style from a string representation
    #[rustfmt::skip]
    fn get_style_string(&mut self, ws: &str) -> Option<WaveStyle> {
        Some(match ws {
            ws if ws == "DEFAULT" || ws == "D" => WaveStyle::Default,
            ws if ws == "ERROR"   || ws == "E" => WaveStyle::Error,
            ws if ws == "HIDDEN"  || ws == "H" => WaveStyle::Hidden,
            ws if ws == "INHERIT" || ws == "I" => WaveStyle::Inherit(0),
            ws if ws.starts_with("I ") => match ws[2..].parse::<u32>() {
                Ok(n) => WaveStyle::Inherit(n as usize),
                Err(_) => {
                    error!("Invalid inherit: {ws}");
                    return None;
                }
            },

            ws if ws == "NORMAL"   || ws == "N" => WaveStyle::Normal,
            ws if ws == "WARN"     || ws == "W" => WaveStyle::Warn,
            ws if ws == "UNDEF"    || ws == "U" => WaveStyle::Undef,
            ws if ws == "HIGHIMP"  || ws == "Z" => WaveStyle::HighImp,
            ws if ws == "WEAK"     || ws == "Q" => WaveStyle::Weak,
            ws if ws == "DONTCARE" || ws == "X" => WaveStyle::DontCare,

            hex if hex.starts_with("#") => match Color32::from_hex(hex) {
                Ok(c) => WaveStyle::Color(c),
                Err(_) => {
                    error!("SHOCKWAVES: Invalid hex code: {hex}");
                    return None;
                }
            },
            var if var.starts_with("$") => return self.get_style_var(&var[1..]),
            col => {
                error!("SHOCKWAVES: Arbitrary color names are currently not surported: {col}");
                return None;
            }
        })
    }

    /// Return whether propagation of the `Error` style is turned on (defaults to true).
    pub fn do_prop_errors(&self) -> bool {
        self.local
            .propagate_errors
            .unwrap_or(self.global.propagate_errors.unwrap_or(true))
    }

    /// Get the spacer override settings for a number format.
    pub fn get_spacer_override(&self, f: &NumberFormat) -> Option<&NumberSpacer> {
        match f {
            NumberFormat::Bin => self
                .local
                .override_bin_spacer
                .as_ref()
                .or(self.global.override_bin_spacer.as_ref()),
            NumberFormat::Oct => self
                .local
                .override_oct_spacer
                .as_ref()
                .or(self.global.override_oct_spacer.as_ref()),
            NumberFormat::Hex => self
                .local
                .override_hex_spacer
                .as_ref()
                .or(self.global.override_hex_spacer.as_ref()),
            NumberFormat::Uns => self
                .local
                .override_uns_spacer
                .as_ref()
                .or(self.global.override_uns_spacer.as_ref()),
            NumberFormat::Sig => self
                .local
                .override_sig_spacer
                .as_ref()
                .or(self.global.override_sig_spacer.as_ref()),
        }
    }
}
