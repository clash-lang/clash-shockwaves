//! Module for converting from Shockwaves types to Surfer types (structures, translations
//! and styles).

use extism_pdk::error;
use surfer_translation_types::{
    SubFieldTranslationResult, TranslationResult, ValueKind, ValueRepr, VariableInfo,
};

use crate::data::*;

impl Structure {
    /// Convert Shockwaves `Structure` to Surfer `VariableInfo`
    pub fn convert(&self) -> VariableInfo {
        if self.0.is_empty() {
            VariableInfo::String
        } else {
            VariableInfo::Compound {
                subfields: self
                    .0
                    .iter()
                    .map(|(name, st)| (name.clone(), st.convert()))
                    .collect(),
            }
        }
    }
}

impl Translation {
    /// Convert a Shockwaves `Translation` value into a Surfer `TranslationResult`
    pub fn convert(self) -> TranslationResult {
        let Translation(render, sub) = self;
        let subfields = sub
            .into_iter()
            .map(|(name, t)| SubFieldTranslationResult {
                name,
                result: t.convert(),
            })
            .collect();
        match render {
            // Hidden style
            Some((_val, WaveStyle::Hidden, _prec)) => TranslationResult {
                val: ValueRepr::NotPresent,
                kind: ValueKind::Normal,
                subfields,
            },
            None => TranslationResult {
                val: ValueRepr::NotPresent,
                kind: ValueKind::Normal,
                subfields,
            },

            // Other styles
            Some((val, style, _prec)) => TranslationResult {
                val: ValueRepr::String(val),
                kind: style.convert(),
                subfields,
            },
        }
    }
}

impl WaveStyle {
    /// Convert a Shockwaves `WaveStyle` into a Surfer `ValueKind`
    fn convert(self) -> ValueKind {
        match self {
            WaveStyle::Default => ValueKind::Normal,
            WaveStyle::Error => ValueKind::Warn,
            WaveStyle::Hidden => unreachable!(),
            WaveStyle::Inherit(_) => unreachable!(),

            WaveStyle::Normal => ValueKind::Normal,
            WaveStyle::Warn => ValueKind::Warn,
            WaveStyle::Undef => ValueKind::Undef,
            WaveStyle::HighImp => ValueKind::HighImp,
            WaveStyle::DontCare => ValueKind::DontCare,
            WaveStyle::Weak => ValueKind::Weak,

            WaveStyle::Color(c) => ValueKind::Custom(c),
            WaveStyle::Var(..) => {
                error!("wavestyle var was not translated!");
                unreachable!()
            }
        }
    }
}
