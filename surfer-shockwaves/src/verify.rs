//! Module for validating translator structures.
//! This should check for everything that is obviously wrong and shouldn't need
//! to be checked while translating.
//! If critical errors (that would cause the extension to panic) are found,
//! the translator is replaced by a constant translator.
//! Also, errors/warnings are printed if the translator widths don't match up
//! in a way that does not cause a crash, but might be incorrect.

use std::collections::HashMap;

use extism_pdk::{error, warn};

use crate::data::*;
use crate::state::State;
use crate::util::CLog;

impl State {
    pub fn verify(&mut self) {
        self.data.verify()
    }
}

impl Data {
    pub fn verify(&mut self) {
        let translators = self
            .types
            .iter()
            .map(|(k, v)| (k.clone(), v.width))
            .collect::<HashMap<String, u32>>();

        self.types
            .iter_mut()
            .for_each(|(source, translator)| translator.verify(source, &translators))
    }
}

impl Translator {
    fn verify(&mut self, source: &str, translators: &HashMap<String, u32>) {
        self.trans.verify(self.width, source, translators)
    }
}

impl TranslatorVariant {
    /// Check Translator variant for errors.
    /// Translators that would cause cause the extension to panic are replaced
    /// by a Const translator with the error message.
    /// Other (potential) problems are reported.
    pub fn verify(&mut self, width: u32, source: &str, translators: &HashMap<String, u32>) {
        if let Err(e) = self.verify2(width, source, translators) {
            error!("SHOCKWAVES: Critical error in translator for {source}: {e}");
            *self = TranslatorVariant::Const(Translation(
                Some(("{".to_owned() + e + "}", WaveStyle::Error, ATOMIC)),
                vec![],
            ));
        }
    }
    fn verify2(
        &mut self,
        width: u32,
        source: &str,
        translators: &HashMap<String, u32>,
    ) -> Result<(), &str> {
        match self {
            TranslatorVariant::Ref(s) => match translators.get(s) {
                Some(w) if *w < width => error!(
                    "SHOCKWAVES: Ref translator for {source:?} has insufficient bits to supply referenced translator"
                ),
                Some(w) if *w > width => {
                    warn!("SHOCKWAVES: Ref translator for {source:?} has unused bits")
                }
                Some(_) => {}
                None => error!(
                    "SHOCKWAVES: Ref translator for {source:?} refers to unknown translator {s:?}"
                ),
            },
            TranslatorVariant::Sum(subs) => {
                if subs.is_empty() {
                    return Err("Sum translator has no subtranslators");
                }
                let tag = subs.len().clog();
                if tag > width {
                    return Err("Sum translator has insufficient bits to select a translator");
                }

                let rest = subs.iter().map(|s| s.width).max().unwrap();
                if rest > width - tag {
                    error!(
                        "SHOCKWAVES: Sum translator for {source:?} has insufficient bits to supply subtranslator"
                    );
                } else if rest < width - tag {
                    warn!("SHOCKWAVES: Sum translator for {source:?} has unused bits");
                }

                subs.iter_mut().for_each(|s| s.verify(source, translators));
            }
            TranslatorVariant::AdvancedSum {
                index: (from, to),
                default_translator,
                range_translators,
            } => {
                if to < from {
                    return Err("AdvancedSum translator index slice of negative length");
                }
                if *to - *from > 128 {
                    return Err("AdvancedSum translator index slice uses more than 128 bits");
                }
                if *to as u32 > width {
                    return Err("AdvancedSum translator has insufficient bits for index slice");
                }

                for ((a, b), _) in range_translators.iter() {
                    if b <= a {
                        warn!(
                            "SHOCKWAVES: AdvancedSum translator for {source} has empty range ({a},{b})"
                        );
                    }
                    if (a + 1).clog() > width {
                        warn!(
                            "SHOCKWAVES: AdvancedSum translator for {source} has range with unreachable lower bound {a}"
                        );
                    }
                }

                default_translator.verify(source, translators);
                range_translators
                    .iter_mut()
                    .for_each(|(_, s)| s.verify(source, translators));
            }
            TranslatorVariant::Product { labels, subs, .. } => {
                if !labels.is_empty() && labels.len() != subs.len() {
                    return Err("Product translator labels field has invalid length");
                }

                let bits: u32 = subs.iter().map(|(_, s)| s.width).sum();
                if bits > width {
                    return Err("Product translator has insufficient bits to supply all fields");
                } else if bits < width {
                    warn!("SHOCKWAVES: Product translator for {source:?} has unused bits");
                }

                subs.iter_mut()
                    .for_each(|(_, s)| s.verify(source, translators));
            }
            TranslatorVariant::AdvancedProduct {
                slice_translators,
                hierarchy,
                value_parts,
                ..
            } => {
                for ((from, to), sub) in slice_translators.iter() {
                    if *to as u32 > width {
                        return Err(
                            "AdvancedProduct translator has insufficient bits for subtranslator slice",
                        );
                    }
                    if to < from {
                        return Err("AdvancedProduct subtranslator slice index of negative length");
                    }
                    if (*to - *from) as u32 != sub.width {
                        warn!(
                            "SHOCKWAVES: AdvancedProduct subtranslator slice does not match subtranslator width"
                        )
                    }
                }

                for (_, i) in hierarchy {
                    if *i >= slice_translators.len() {
                        return Err("AdvancedProduct hierarchy has invalid translator index");
                    }
                }

                for vp in value_parts {
                    if let ValuePart::Ref(i, _) = vp
                        && *i >= slice_translators.len()
                    {
                        return Err("AdvancedProduct ValuePart Ref has invalid translator index");
                    }
                }

                slice_translators
                    .iter_mut()
                    .for_each(|(_, s)| s.verify(source, translators))
            }
            TranslatorVariant::Const(..) => { /* cannot fail */ }
            TranslatorVariant::Lut(..) => {
                // Properly checking the LUT would be difficult (take a lot of calculations)
                // Luts don't cause errors unless the Structure misses signals used in the values
                // The only way to verify this is to go over all stored values, which is a tad
                // much.
            }
            TranslatorVariant::Number { spacer, .. } => {
                if width == 0 {
                    warn!("SHOCKWAVES: Number translator for {source:?} has 0 bits");
                }
                match spacer {
                    Some((0, s)) if !s.is_empty() => {
                        warn!("SHOCKWAVES: Number spacer has unused value {s:?}")
                    }
                    Some((n, s)) if s.is_empty() && *n > 0 => {
                        warn!("SHOCKWAVES: Number spacer empty but nonzero")
                    }
                    _ => {}
                }
            }
            TranslatorVariant::Array { sub, len, .. } => {
                if sub.width * *len > width {
                    return Err("Array translator has insufficient bits to supply all fields");
                }
                if sub.width * *len < width {
                    warn!("SHOCKWAVES: Array translator for {source:?} has unused bits");
                }

                sub.verify(source, translators)
            }
            TranslatorVariant::Styled(_, sub) => {
                if sub.width > width {
                    error!(
                        "SHOCKWAVES: Styled translator for {source:?} has insufficient bits to supply subtranslator"
                    );
                } else if sub.width < width {
                    warn!("SHOCKWAVES: Styled translator for {source:?} has unused bits")
                }

                sub.verify(source, translators)
            }
            TranslatorVariant::Duplicate(_, sub) => {
                if sub.width > width {
                    error!(
                        "SHOCKWAVES: Duplicate translator for {source:?} has insufficient bits to supply subtranslator"
                    );
                } else if sub.width < width {
                    warn!("SHOCKWAVES: Duplicate translator for {source:?} has unused bits")
                }

                sub.verify(source, translators)
            }
            TranslatorVariant::ChangeBits { sub, bits } => {
                let b = bits.verify(width, source)?;
                match b {
                    Some(w) if w < sub.width => error!(
                        "SHOCKWAVES: ChangeBits translator for {source:?} produces insufficient bits for subtranslator"
                    ),
                    Some(w) if w > sub.width => {
                        warn!(
                            "SHOCKWAVES: ChangeBits translator for {source:?} produces unused bits"
                        )
                    }
                    Some(_) => {}
                    None => warn!(
                        "SHOCKWAVES: ChangeBits translator for {source:?} may produce a variable number of bits"
                    ),
                }

                sub.verify(source, translators)
            }
        }
        Ok(())
    }
}

impl BitPart {
    /// verify a BitPart, returning the bitsize if known
    pub fn verify(&mut self, inputsize: u32, source: &str) -> Result<Option<u32>, &str> {
        match self {
            BitPart::In => Ok(Some(inputsize)),
            BitPart::Lit(l) => {
                *l = l
                    .chars()
                    .map(|c| {
                        if "01x".contains(c) {
                            c
                        } else {
                            error!("SHOCKWAVES: ChangeBits BitPart literal for {source:?} contains unknown character {c:?}");
                            'x'
                        }
                    })
                    .collect();
                Ok(Some(l.len() as u32))
            }
            BitPart::Concat(subs) => Ok(subs
                .iter_mut()
                .map(|s| s.verify(inputsize, source))
                .collect::<Result<Option<Vec<_>>, &str>>()?
                .map(|v| v.iter().sum())),
            BitPart::Slice((from, to), sub) => {
                if to < from {
                    return Err("BitPart Slice of negative length");
                }
                match sub.verify(inputsize, source)? {
                    Some(w) if w < *to as u32 => return Err("Slice receives insufficient bits"),
                    Some(_) => {}
                    None => warn!(
                        "SHOCKWAVES: ChangeBits BitPart Slice for {source:?} may receive insufficient bits; if this happens, the entire slice will be undefined"
                    ),
                }
                Ok(Some((*to - *from) as u32))
            }
            BitPart::HasUndefined(sub) => {
                if sub.verify(inputsize, source)?.is_none() {
                    warn!(
                        "SHOCKWAVES: ChangeBits BitPart HasUndefined for {source:?} may receive a variable number of bits"
                    )
                }
                Ok(Some(1))
            }
            BitPart::Reverse(sub) | BitPart::Invert(sub) => sub.verify(inputsize, source),
            BitPart::And(subs) | BitPart::Or(subs) | BitPart::Xor(subs) => {
                let len = subs
                    .iter_mut()
                    .map(|s| s.verify(inputsize, source))
                    .collect::<Result<Option<Vec<_>>, &str>>()?
                    .map(|l| l.iter().max().copied());
                match len {
                    None => Ok(None),
                    Some(Some(x)) => Ok(Some(x)),
                    Some(None) => Err("BitPart And/Or/Xor must have at least one sub-bitpart"),
                }
            }
            BitPart::OneHot((from, to), sub) | BitPart::NHot((from, to), sub) => {
                if to < from {
                    return Err("(N)Hot range of negative length");
                }
                if let Some(w) = sub.verify(inputsize, source)? {
                    if w > 128 {
                        return Err("(N)Hot encoding is provided more than 128 bits");
                    }
                } else {
                    warn!(
                        "SHOCKWAVES: ChangeBits BitPart (N)Hot for {source:?} may receive more than 128 bits; if the value overflows the size of a 128 bit unsigned, the result will be completely undefined"
                    );
                }
                Ok(Some((*to - *from) as u32))
            }
            BitPart::If { t, f, x, c } => {
                if let Some(w) = c.verify(inputsize, source)?
                    && w == 0
                {
                    warn!(
                        "SHOCKWAVES: BitPart If condition input for {source:?} has no bits and is always treated as undefined"
                    );
                }
                if let (Some(t), Some(f), Some(x)) = (
                    t.verify(inputsize, source)?,
                    f.verify(inputsize, source)?,
                    x.verify(inputsize, source)?,
                ) && t == f
                    && f == x
                {
                    return Ok(Some(t));
                }
                Ok(None)
            }
        }
    }
}
