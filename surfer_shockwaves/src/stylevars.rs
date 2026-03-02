//! Module for replacing style variables with actual styles as defined in config files.
//! Note that most code for reading the style variable configuration files is located
//! in `config.rs`.

use crate::config::*;
use crate::data::*;
use crate::state::*;

impl WaveStyle {
    /// Replace a style variable with actual wavestyles.
    fn replace_wavestyles(&mut self, conf: &mut Config) {
        if let WaveStyle::Var(..) = self {
            *self = conf.get_style(self);
        }
    }
}

impl Translation {
    /// Replace style variables with actual wavestyles.
    pub fn replace_wavestyles(&mut self, conf: &mut Config) {
        if let Some((_, s, _)) = self.0.as_mut() {
            s.replace_wavestyles(conf);
        }
        self.1
            .iter_mut()
            .for_each(|(_, t)| t.replace_wavestyles(conf));
    }
}

impl TranslatorVariant {
    /// Replace style variables with actual wavestyles.
    fn replace_wavestyles(&mut self, conf: &mut Config) {
        match self {
            TranslatorVariant::Ref(_) => {}
            TranslatorVariant::Sum(subs) => {
                subs.iter_mut().for_each(|t| t.replace_wavestyles(conf))
            }
            TranslatorVariant::AdvancedSum {
                default_translator,
                range_translators,
                ..
            } => {
                default_translator.replace_wavestyles(conf);
                range_translators
                    .iter_mut()
                    .for_each(|(_, t)| t.replace_wavestyles(conf));
            }
            TranslatorVariant::Product { subs, .. } => subs
                .iter_mut()
                .for_each(|(_, t)| t.replace_wavestyles(conf)),
            TranslatorVariant::AdvancedProduct {
                slice_translators, ..
            } => slice_translators
                .iter_mut()
                .for_each(|(_, t)| t.replace_wavestyles(conf)),
            TranslatorVariant::Const(t) => t.replace_wavestyles(conf),
            TranslatorVariant::Lut(..) => {}
            TranslatorVariant::Number { .. } => {}
            TranslatorVariant::Array { sub, .. } => sub.replace_wavestyles(conf),
            TranslatorVariant::Styled(style, translator) => {
                style.replace_wavestyles(conf);
                translator.replace_wavestyles(conf);
            }
            TranslatorVariant::Duplicate(_, t) => t.replace_wavestyles(conf),
            TranslatorVariant::ChangeBits { sub, .. } => sub.replace_wavestyles(conf),
        }
    }
}

impl Translator {
    /// Replace style variables with actual wavestyles.
    pub fn replace_wavestyles(&mut self, conf: &mut Config) {
        self.trans.replace_wavestyles(conf);
    }
}

impl State {
    /// Replace style variables with actual wavestyles.
    pub fn replace_wavestyles(&mut self) {
        for translator in self.data.types.values_mut() {
            translator.replace_wavestyles(&mut self.config);
        }
        for lut in self.data.luts.values_mut() {
            for trans in lut.values_mut() {
                trans.replace_wavestyles(&mut self.config);
            }
        }
    }
}
