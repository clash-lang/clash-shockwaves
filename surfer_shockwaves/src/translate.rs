//! Module containing all translation machinery.

use extism_pdk::error;
use surfer_translation_types::TranslationResult;

use lazy_static::lazy_static;
use num_bigint::{BigInt, BigUint};
use std::iter::zip;

use crate::data::*;
use crate::state::*;

lazy_static! {
    // Constant "default" value for missing translators
    static ref TRANSLATOR_NOT_FOUND: Translator = Translator {
        width: 0,
        trans: TranslatorVariant::Const(error("{translator not found}")),
    };
}

/// Get the value of a translation, wrapped in parentheses if the outer precedence
/// is not lower.
fn val_with_prec(translation: &Translation, preco: Prec) -> Vec<&str> {
    match &translation.0 {
        Some((value, _, preci)) => {
            if *preci > preco {
                vec![value]
            } else {
                vec!["(", value, ")"]
            }
        }
        None => vec!["{value missing}"],
    }
}

/// Create a translation from an error message. Its value is regarded as atomic.
fn error(msg: &str) -> Translation {
    Translation(Some((String::from(msg), WaveStyle::Error, ATOMIC)), vec![])
}

/// Translate binary data as an integer.
fn translate_number(value: &str, format: &NumberFormat, spacer: &NumberSpacer) -> Translation {
    let apply_spacer = |v: String| match spacer {
        None => v,
        Some((0, _)) => v,
        Some((n, s)) => {
            let n = *n as i32;
            let mut chunks = vec![];
            let mut i = v.len() as i32;
            while i > 0 {
                chunks.push(&v[0i32.max(i - n) as usize..i as usize]);
                i -= n;
            }
            let mut res = vec![];
            for i in 0..chunks.len() {
                res.push(chunks[i]);
                if i + 1 < chunks.len() && chunks[i + 1] != "-" {
                    res.push(s);
                }
            }
            res.reverse();
            res.join("")
        }
    };

    Translation(
        Some(match format {
            NumberFormat::Sig => {
                // slightly cursed way of doing this - convert to base 256 (bytes), then to bigint, then to string
                let n = value.len().div_ceil(8);
                let mut bytes = vec![0u8; n];
                for i in 0..(8 * n) {
                    let j = if i >= value.len() {
                        0 //sign extend by saturating index to end
                    } else {
                        value.len() - 1 - i
                    };
                    let c = value.chars().nth(j);
                    if c == Some('1') {
                        bytes[i / 8] |= (1 << (i % 8)) as u8;
                    } else if c == Some('0') {
                        //pass
                    } else {
                        return error("unknown");
                    }
                }

                let big = BigInt::from_signed_bytes_le(&bytes);
                let bigstr = big.to_string();
                let prec = if bigstr.starts_with('-') { 0 } else { ATOMIC };

                (apply_spacer(bigstr), WaveStyle::Default, prec)
            }
            NumberFormat::Uns => {
                if value.is_empty() {
                    ("0".to_string(), WaveStyle::Default, ATOMIC)
                } else {
                    match BigUint::parse_bytes(value.as_bytes(), 2) {
                        Some(big) => (apply_spacer(big.to_string()), WaveStyle::Default, ATOMIC),
                        None => return error("unknown"),
                    }
                }
            }
            NumberFormat::Bin => (
                "0b".to_owned() + &apply_spacer(value.to_string()),
                if value.contains('x') {
                    WaveStyle::Error
                } else {
                    WaveStyle::Default
                },
                ATOMIC,
            ),
            NumberFormat::Hex | NumberFormat::Oct => {
                let (chunksize, prefix) = match format {
                    NumberFormat::Oct => (3, "0o"),
                    NumberFormat::Hex => (4, "0X"),
                    _ => unreachable!(),
                };
                let mut blocks = vec![];
                let mut block = vec![];
                for (i, c) in value.chars().enumerate() {
                    block.push(format!("{}", c));
                    if (value.len() - i - 1).is_multiple_of(chunksize) {
                        let chunk = block.concat();
                        blocks.push(match u8::from_str_radix(&chunk, 2) {
                            Ok(n) => format!("{:x}", n),
                            Err(_) => "x".to_string(),
                        });
                        block.clear();
                    }
                }

                let val = prefix.to_owned() + &apply_spacer(blocks.concat());
                let style = if val.contains("x") {
                    WaveStyle::Error
                } else {
                    WaveStyle::Default
                };
                (val, style, ATOMIC)
            }
        }),
        vec![],
    )
}

impl ValuePart {
    /// Determine the value of a value part.
    fn make_value(&self, translations: &[Translation]) -> String {
        match self {
            ValuePart::Lit(s) => s.clone(),
            ValuePart::Ref(i, p) => val_with_prec(&translations[*i], *p).concat(),
        }
    }
}

impl BitPart {
    /// Manipulate bits according to the `BitPart` structure.
    fn from(&self, bits: &str) -> String {
        match self {
            BitPart::Concat(bps) => bps
                .iter()
                .map(|bp| bp.from(bits))
                .collect::<Vec<_>>()
                .concat(),
            BitPart::Lit(s) => s.to_string(),
            BitPart::Slice((a, b)) => bits[*a..*b].to_string(),
        }
    }
}

impl Data {
    /// Check whether a signal has a known associated type.
    pub fn can_translate(&self, signal: &str) -> bool {
        self.signals.contains_key(signal)
    }

    /// Get the type of a signal.
    pub fn get_type(&self, signal: &str) -> Option<&String> {
        self.signals.get(signal)
    }

    /// Get the translator of a signal. If there is no such translator, return a
    /// default translator that displays an error message.
    pub fn get_translator(&self, ty: &str) -> &Translator {
        match self.types.get(ty) {
            Some(t) => t,
            None => &TRANSLATOR_NOT_FOUND,
        }
    }
}

impl Translation {
    /// Fill out a translation according to the provided Structure. Currently O(n^2).
    pub fn fill(&mut self, structure: &Structure) {
        let ssub = &structure.0;

        // recursively fill out provided subsignals
        for (n, t) in &mut self.1 {
            for (n2, s) in ssub {
                if n == n2 {
                    t.fill(s);
                    break;
                }
            }
        }

        // add missing subsignals
        'outer: for (n, s) in ssub {
            for (n2, _) in &self.1 {
                if n == n2 {
                    continue 'outer;
                }
            }
            self.1.push((n.clone(), Translation::from_struct(s)))
        }
    }

    /// Create an empty translation from a structure.
    fn from_struct(structure: &Structure) -> Self {
        Translation(
            None,
            structure
                .0
                .iter()
                .map(|(n, s)| (n.clone(), Translation::from_struct(s)))
                .collect(),
        )
    }

    /// Propagate error style upwards through the signal hierarchy.
    pub fn prop_errors(&mut self) -> bool {
        if self.1.iter_mut().any(|(_n, t)| t.prop_errors()) {
            if let Some((_, s, _)) = &mut self.0 {
                *s = WaveStyle::Error;
            }
            return true;
        }
        matches!(self.0, Some((_, WaveStyle::Error, _)))
    }

    /// Fill in inherited styles.
    pub fn prop_style_inherit(&mut self) {
        self.1.iter_mut().for_each(|(_n, t)| t.prop_style_inherit());

        let n = if let Some((_val, WaveStyle::Inherit(n), _p)) = &self.0 {
            n
        } else {
            return;
        };

        self.0.as_mut().unwrap().1 =
            if let Some((_name, Translation(Some((_v, s, _p)), _))) = self.1.get(*n) {
                s.clone()
            } else {
                error!("Attempt to inherit style from nonexistent subsignal {n}");
                WaveStyle::Warn
            };
    }
}

impl State {
    /// Translate a value.
    pub fn translate(&mut self, signal: &str, value: &str) -> TranslationResult {
        let ty = self.data.get_type(signal).unwrap().clone();
        let translator = self.data.get_translator(&ty);
        let mut translation = self.translate_with(translator, value);

        //propagate styles
        if self.config.do_prop_errors() {
            translation.prop_errors();
        }
        translation.prop_style_inherit();

        //fill out missing unknown fields
        let structure = self
            .cache
            .structures
            .entry(ty.clone())
            .or_insert_with(|| self.data.type_structure(&ty));
        translation.fill(structure);

        translation.convert()
    }

    /// Translate a value using the provided translator.
    pub fn translate_with(
        &self,
        Translator { width, trans }: &Translator,
        value: &str,
    ) -> Translation {
        // Note that excess bits will be silently truncated; this is intended
        // behavior that usually appears when a Sum translator translates a
        // constructor that's smaller than other constructors.
        if (*width as usize) > value.len() {
            return error("{insufficient bits}");
        }
        let value = &value[..(*width as usize)];

        match trans {
            /* Direct translators */
            TranslatorVariant::Ref(ty) => self.translate_with(self.data.get_translator(ty), value),
            TranslatorVariant::Const(t) => t.clone(),
            TranslatorVariant::Number { format, spacer } => {
                let spacer = self.config.get_spacer_override(format).unwrap_or(spacer);
                translate_number(value, format, spacer)
            }
            TranslatorVariant::Lut(n, _) => match self.data.luts.get(n) {
                Some(lut) => match lut.get(value) {
                    Some(t) => t.clone(),
                    None => error("{value missing from LUT}"),
                },
                None => error("{unknown LUT}"),
            },
            /* Product translators */
            TranslatorVariant::Product {
                subs,
                start,
                sep,
                stop,
                labels,
                preci,
                preco,
            } => {
                let mut sub = vec![];
                let _ = subs.iter().fold(0usize, |i, (n, t)| {
                    let translation = self.translate_with(t, &value[i..]);
                    sub.push((n.clone(), translation));
                    i + t.width as usize
                });

                let vals: Vec<&str> = if !labels.is_empty() {
                    let mut res: Vec<&str> = vec![start];
                    for (i, (l, (_, t))) in zip(0.., zip(labels, sub.iter())) {
                        res.push(l);
                        res.extend(val_with_prec(t, *preci));
                        if i != subs.len() - 1 {
                            res.push(sep);
                        }
                    }
                    res.push(stop);
                    res
                } else {
                    let mut res: Vec<&str> = vec![start];
                    for (i, (_, t)) in zip(0.., sub.iter()) {
                        res.extend(val_with_prec(t, *preci));
                        if i != subs.len() - 1 {
                            res.push(sep);
                        }
                    }
                    res.push(stop);
                    res
                };
                let val = vals.concat(); //join("");

                Translation(
                    Some((val, WaveStyle::Default, *preco)),
                    // filter out subsignals without labels
                    sub,
                )
            }
            TranslatorVariant::AdvancedProduct {
                slice_translators,
                hierarchy,
                value_parts,
                preco,
            } => {
                let translations: Vec<_> = slice_translators
                    .iter()
                    .map(|((a, b), t)| self.translate_with(t, &value[*a..*b]))
                    .collect();

                let value = value_parts
                    .iter()
                    .map(|vp| vp.make_value(&translations))
                    .collect::<Vec<_>>()
                    .concat();

                let subs = hierarchy
                    .iter()
                    .map(|(n, i)| (n.clone(), translations[*i].clone()))
                    .collect();
                Translation(Some((value, WaveStyle::Default, *preco)), subs)
            }
            TranslatorVariant::Array {
                sub,
                len,
                start,
                sep,
                stop,
                preci,
                preco,
            } => {
                let mut subs = vec![];
                for i in 0u32..*len {
                    subs.push(self.translate_with(sub, &value[(i * sub.width) as usize..]));
                }

                let mut res: Vec<&str> = vec![start];
                for (i, t) in zip(0.., subs.iter()) {
                    res.extend(val_with_prec(t, *preci));
                    if i != subs.len() - 1 {
                        res.push(sep);
                    }
                }
                res.push(stop);

                Translation(
                    Some((res.join(""), WaveStyle::Default, *preco)),
                    subs.into_iter()
                        .enumerate()
                        .map(|(i, t)| (format!("{i}"), t))
                        .collect(),
                )
            }
            /* Sum translators */
            TranslatorVariant::Sum(translators) => {
                if translators.is_empty() {
                    return error("{no subtranslators}");
                }
                let n = translators.len();
                let bits = (usize::BITS - (n - 1).leading_zeros()) as usize;
                let variant = if bits > 0 {
                    usize::from_str_radix(&value[..bits], 2)
                } else {
                    Ok(0)
                };
                match variant {
                    Ok(variant) => {
                        if variant >= n {
                            return error("{variant out of range}");
                        }
                        let t = &translators[variant];
                        self.translate_with(t, &value[bits..])
                    }
                    Err(_) => error("unknown"),
                }
            }
            TranslatorVariant::AdvancedSum {
                index: (a, b),
                default_translator,
                range_translators,
            } => match u128::from_str_radix(&value[*a..*b], 2) {
                Ok(key) => {
                    for ((lo, hi), translator) in range_translators {
                        if *lo <= key && key < *hi {
                            return self.translate_with(translator, value);
                        }
                    }
                    self.translate_with(default_translator, value)
                }
                Err(_) => error("unknown"),
            },
            /* Manipulating translators */
            TranslatorVariant::Duplicate(n, t) => {
                let translation = self.translate_with(t, value);
                let render = translation
                    .0
                    .as_ref()
                    .map(|(v, _, p)| (v.clone(), WaveStyle::Inherit(0), *p));
                Translation(render, vec![(n.clone(), translation)])
            }
            TranslatorVariant::Styled(s, t) => {
                let translation = self.translate_with(t, value);
                match translation {
                    Translation(Some((v, _, p)), sub) => Translation(Some((v, s.clone(), p)), sub),
                    trans => trans,
                }
            }
            TranslatorVariant::ChangeBits { sub, bits } => {
                self.translate_with(sub, &bits.from(value))
            }
        }
    }
}
