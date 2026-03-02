//! Module for handling signal structures.

use surfer_translation_types::VariableInfo;

use crate::data::*;
use crate::state::*;

impl Structure {
    /// Generate a structure from a translation.
    fn from_trans(trans: &Translation) -> Self {
        Structure(
            trans
                .1
                .iter()
                .map(|(n, t)| (n.clone(), Self::from_trans(t)))
                .collect(),
        )
    }
}

impl Data {
    /// Get the structure of a type.
    pub fn type_structure(&self, ty: &str) -> Structure {
        let trans = self.get_translator(ty);
        self.trans_structure(trans)
    }

    /// Get the structure of a translator.
    pub fn trans_structure(&self, trans: &Translator) -> Structure {
        let Translator { trans, .. } = trans;
        match trans {
            /* Direct translators */
            TranslatorVariant::Ref(ty) => self.type_structure(ty),
            TranslatorVariant::Const(t) => Structure::from_trans(t),
            TranslatorVariant::Lut(_, structure) => structure.clone(),
            TranslatorVariant::Number { .. } => Structure(vec![]),
            /* Product translators */
            TranslatorVariant::Product { subs, .. } => Structure(
                subs.iter()
                    .map(|(name, t)| (name.clone(), self.trans_structure(t)))
                    .collect(),
            ),
            TranslatorVariant::AdvancedProduct {
                slice_translators,
                hierarchy,
                ..
            } => Structure(
                hierarchy
                    .iter()
                    .map(|(n, i)| (n.clone(), self.trans_structure(&slice_translators[*i].1)))
                    .collect(),
            ),
            TranslatorVariant::Array { sub, len, .. } => Structure(
                std::iter::repeat_n(self.trans_structure(sub), *len as usize)
                    .enumerate()
                    .map(|(i, s)| (i.to_string(), s))
                    .collect(),
            ),
            /* Sum translators */
            TranslatorVariant::Sum(translators) => {
                let ts = translators
                    .iter()
                    .flat_map(|t| self.trans_structure(t).0)
                    .collect();
                Structure(ts)
            }
            TranslatorVariant::AdvancedSum {
                default_translator,
                range_translators,
                ..
            } => {
                let mut ts: Vec<_> = range_translators
                    .iter()
                    .flat_map(|(_, t)| self.trans_structure(t).0)
                    .collect();
                ts.extend(self.trans_structure(default_translator).0);
                Structure(ts)
            }
            /* Manipulating translators */
            TranslatorVariant::Styled(_, translator) => self.trans_structure(translator),
            TranslatorVariant::Duplicate(name, translator) => {
                Structure(vec![(name.clone(), self.trans_structure(translator))])
            }
            TranslatorVariant::ChangeBits { sub, .. } => self.trans_structure(sub),
        }
    }
}

impl State {
    /// Determine the structure of a signal.
    pub fn structure(&mut self, signal: &str) -> VariableInfo {
        let ty = self.data.get_type(signal).unwrap();

        // try to return structure from cache
        if let Some(st) = self.cache.structures.get(ty) {
            return st.convert();
        }

        // determine and store the structure
        let trans = self.data.get_translator(ty);
        let st = self.data.trans_structure(trans);
        let ty = ty.clone();

        let st = self.cache.structures.entry(ty).or_insert(st);

        st.convert()
    }
}
