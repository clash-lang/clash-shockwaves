//! All types for VCD Metadata (translators, signals, and LUTs)

use egui::Color32;
use serde::Deserialize;
use serde::de::{Deserializer, Error};
use std::collections::HashMap;

pub type SigMap = HashMap<String, String>;
pub type TypeMap = HashMap<String, Translator>;
pub type LutMap = HashMap<String, Lut>;

pub type Lut = HashMap<String, Translation>;

/// Object containing all metadata for translating binary VCD values:
/// - the type of each signal
/// - the translator of each type
/// - any LUTs needed for translation
#[derive(Deserialize, Debug)]
pub struct Data {
    pub signals: SigMap,
    pub types: TypeMap,
    pub luts: LutMap,
}

/// The complete translation, including any subsignals, of a binary value.
#[derive(Deserialize, Debug, Clone)]
pub struct Translation(pub Render, pub Vec<(String, Translation)>);

/// The visual representation of the value on a single waveform line.
pub type Render = Option<(Value, WaveStyle, Prec)>;
pub type Value = String;

/// The style (which determine the color of the waveform).
#[derive(Deserialize, Debug, Clone)]
pub enum WaveStyle {
    #[serde(alias = "D")]
    Default,
    #[serde(alias = "E")]
    Error,
    #[serde(alias = "H")]
    Hidden,
    #[serde(alias = "I")]
    Inherit(usize),

    #[serde(alias = "N")]
    Normal,
    #[serde(alias = "W")]
    Warn,
    #[serde(alias = "U")]
    Undef,
    #[serde(alias = "Z")]
    HighImp,
    #[serde(alias = "X")]
    DontCare,
    #[serde(alias = "Q")]
    Weak,

    #[serde(alias = "C")]
    Color(Color32),
    #[serde(alias = "V")]
    Var(String, Box<WaveStyle>),
}

/// Operator precedence
pub type Prec = i16;
/// Precedence of an atomic (a number, an identifier, somthing between parentheses)
pub const ATOMIC: Prec = 11;
pub const DEFAULT_SIG_NEG_PREC: Prec = ATOMIC; // not the haskell default of 6!

/// A construct for turning binary values into translations.
#[derive(Deserialize, Debug)]
pub struct Translator {
    #[serde(alias = "w")]
    pub width: u32,
    #[serde(alias = "t")]
    #[serde(alias = "v")]
    pub trans: TranslatorVariant,
}

/// The different types of translators
#[derive(Deserialize, Debug)]
pub enum TranslatorVariant {
    #[serde(alias = "R")]
    Ref(String),

    #[serde(alias = "S")]
    Sum(Vec<Translator>),

    #[serde(alias = "S+")]
    AdvancedSum {
        #[serde(alias = "i")]
        index: (usize, usize),
        #[serde(alias = "d")]
        default_translator: Box<Translator>,
        #[serde(alias = "t")]
        range_translators: Vec<((u128, u128), Translator)>,
    },

    #[serde(alias = "P")]
    Product {
        #[serde(alias = "t")]
        subs: Vec<(String, Translator)>,
        #[serde(alias = "[")]
        start: String,
        #[serde(alias = ",")]
        sep: String,
        #[serde(alias = "]")]
        stop: String,
        #[serde(alias = "n")]
        labels: Vec<String>,
        #[serde(alias = "p")]
        preci: Prec,
        #[serde(alias = "P")]
        preco: Prec,
    },

    #[serde(alias = "P+")]
    AdvancedProduct {
        #[serde(alias = "t")]
        slice_translators: Vec<((usize, usize), Translator)>,
        #[serde(alias = "h")]
        hierarchy: Vec<(String, usize)>,
        #[serde(alias = "v")]
        value_parts: Vec<ValuePart>,
        #[serde(alias = "P")]
        preco: Prec,
    },

    #[serde(alias = "C")]
    Const(Translation),

    #[serde(alias = "L")]
    Lut(String, Structure),

    #[serde(alias = "N")]
    Number {
        #[serde(alias = "f")]
        format: NumberFormat,
        #[serde(alias = "s", default)]
        spacer: NumberSpacer,
        #[serde(alias = "p", default)]
        prefix: String,
        #[serde(alias = "w", default)]
        warn: bool,
    },

    #[serde(alias = "A")]
    Array {
        #[serde(alias = "t")]
        sub: Box<Translator>,
        #[serde(alias = "l")]
        len: u32,
        #[serde(alias = "[")]
        start: String,
        #[serde(alias = ",")]
        sep: String,
        #[serde(alias = "]")]
        stop: String,
        #[serde(alias = "p")]
        preci: Prec,
        #[serde(alias = "P")]
        preco: Prec,
    },

    #[serde(alias = "X")]
    Styled(WaveStyle, Box<Translator>),

    #[serde(alias = "D")]
    Duplicate(String, Box<Translator>),

    #[serde(alias = "B")]
    ChangeBits {
        #[serde(alias = "t")]
        sub: Box<Translator>,
        #[serde(alias = "b")]
        bits: BitPart,
    },
}

/// A part of a value (for `AdvancedProduct`).
#[derive(Deserialize, Debug, Clone)]
pub enum ValuePart {
    #[serde(alias = "L")]
    Lit(String),
    #[serde(alias = "R")]
    Ref(usize, Prec),
}

/// A transformation on a binary value (for `ChangeBits`).
#[derive(Deserialize, Debug, Clone)]
pub enum BitPart {
    #[serde(alias = "I")]
    In,
    #[serde(alias = "C")]
    Concat(Vec<BitPart>),
    #[serde(alias = "L")]
    Lit(String),
    #[serde(alias = "S")]
    Slice((usize, usize), Box<BitPart>),
    #[serde(alias = "X")]
    HasUndefined(Box<BitPart>),
    #[serde(alias = "R")]
    Reverse(Box<BitPart>),
    #[serde(alias = "~")]
    Invert(Box<BitPart>),
    #[serde(alias = "&")]
    And(Vec<BitPart>),
    #[serde(alias = "|")]
    Or(Vec<BitPart>),
    #[serde(alias = "^")]
    Xor(Vec<BitPart>),
    #[serde(alias = "h")]
    OneHot((u128, u128), Box<BitPart>),
    #[serde(alias = "H")]
    NHot((u128, u128), Box<BitPart>),
    #[serde(alias = "?")]
    If {
        t: Box<BitPart>,
        f: Box<BitPart>,
        x: Box<BitPart>,
        c: Box<BitPart>,
    },
}

/// A number format (integers only).
#[derive(Deserialize, Debug, Clone, Copy)]
#[serde(remote = "NumberFormat")]
pub enum NumberFormat {
    Sig(Prec),
    Uns,
    Hex,
    Oct,
    Bin,
}

impl<'de> Deserialize<'de> for NumberFormat {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let val = serde_json::Value::deserialize(deserializer)?;
        match val {
            serde_json::Value::String(s) if s == "U" || s == "Uns" => Ok(NumberFormat::Uns),
            serde_json::Value::String(s) if s == "H" || s == "Hex" => Ok(NumberFormat::Hex),
            serde_json::Value::String(s) if s == "O" || s == "Oct" => Ok(NumberFormat::Oct),
            serde_json::Value::String(s) if s == "B" || s == "Bin" => Ok(NumberFormat::Bin),
            serde_json::Value::String(s) if s == "S" || s == "Sig" => {
                Ok(NumberFormat::Sig(DEFAULT_SIG_NEG_PREC))
            }
            serde_json::Value::Object(m) if m.len() == 1 => {
                if let Some(serde_json::Value::Number(p)) = m.get("Sig").or(m.get("S")) {
                    Ok(NumberFormat::Sig(
                        p.as_i64()
                            .ok_or_else(|| D::Error::custom("Precedence outside range"))?
                            as i16,
                    ))
                } else {
                    Err(D::Error::custom(
                        "Could not deserialize number format from map",
                    ))
                }
            }
            _ => Err(D::Error::custom("Could not deserialize number format")),
        }
    }
}

/// What spacer, if any, to use, to make large numbers more legible.
pub type NumberSpacer = Option<(u32, String)>;

#[derive(Deserialize, Debug, Clone)]
pub struct Structure(pub Vec<(String, Structure)>);

impl Data {
    pub fn new() -> Self {
        Self {
            signals: HashMap::new(),
            types: HashMap::new(),
            luts: HashMap::new(),
        }
    }
}
