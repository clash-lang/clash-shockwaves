//! Module for validating translator structures.
//! This should check for everything that is obviously wrong and shouldn't need
//! to be checked while translating.
//! If critical errors (that would cause the extension to panic) are found,
//! the translator is replaced by a constant translator.
//! Also, errors/warnings are printed if the translator widths don't match up
//! in a way that does not cause a crash, but might be incorrect.

use extism_pdk::error;
use crate::data::*;
use crate::util::clog;

impl State {
    fn validate(&mut self) {
        self.data.validate()
    }
}

impl Data {
    fn validate(&mut self) {
        let translators : HashMap<String,u32> = self.types.iter().map(|k,v| (k,v.width)).collect();

        self.types.iter_mut().for_each(|source,translator| translator.validate(source,translators))
    }
}


impl Translator {
    fn validate(&mut self, source: &str, translators: &HashMap<String,u32>) {
        self.trans.validate(self.width, source)
    }
}

impl TranslatorVariant {
    /// Check Translator variant for errors.
    /// Translators that would cause cause the extension to panic are replaced
    /// by a Const translator with the error message.
    /// Other (potential) problems are reported.
    fn validate(&mut self, width: u32, source: &str, translators: &HashMap<String,u32>) {
        fn validate2(&mut self, width: u32, source: &str, translators: &HashMap<String,u32>) -> Result<(),&str> {
            match self {
                TranslatorVariant::Ref(s) => {
                    match translators.get(s) {
                        Some(w) if w < width => error!("Ref translator for {source:?} has insufficient bits to supply referenced translator")
                        Some(w) if w > width => warn!("Ref translator for {source:?} has unused bits")
                        Some(w) => {} 
                        None => error!("Ref translator for {source:?} refers to unknown translator {s:?}")
                    }
                }
                TranslatorVariant::Sum(subs) => {
                    if subs.is_empty() {
                        return Err("Sum translator has no subtranslators")
                    }
                    let tag = subs.len().clog();
                    if tag > width {
                        return Err("Sum translator has insufficient bits to select a translator")
                    }

                    let rest = subs.iter().map(|s| s.width).max();
                    if rest > tag {
                        error!("Sum translator for {source:?} has insufficient bits to supply subtranslator");
                    } else if rest < tag {
                        warn!("Sum translator for {source:?} has unused bits");
                    }

                    subs.iter_mut().for_each(|s| s.validate(source,translators));
                }
                TranslatorVariant::AdvancedSum(..) => {
                    // index is a valid slice given the number of bits
                    // warn if index slices are weird/useless (invalid slice may be used to manipulate subsignals)
                    // recurse over default translator and subtranslators

                    ...
                }
                TranslatorVariant::Product{labels,subs} => {
                    if !labels.is_empty() && labels.len() != subs.len() {
                        return Err("Product translator labels has invalid length")
                    }

                    let bits = subs.iter().map(|s| s.width).sum();
                    if bits > width {
                        return Err("Product translator has insufficient bits to supply all fields")
                    } else if bits < width {
                        warn!("Product translator for {source:?} has unused bits")
                    }

                    subs.iter_mut().for_each(|s| s.validate(source,translators));
                }
                TranslatorVariant::AdvancedProduct(..) {
                    // check slices
                    // check hierarchy indices
                    // similarly check valueparts
                        // check internal indices

                    // + check slice widths against their translators

                    ...
                }
                TranslatorVariant::Const(..) {/* cannot fail */}
                TranslatorVariant::Lut(..) {
                    // check that lut exists
                    // verifying structure is basically impossible
                    //  without checking all values that are stored,
                    //  which is not worth the effort. Probably.
                        // + check bitsize?
                    
                    ...
                }
                TranslatorVariant::Number{spacer,..} {
                    if width==0 {
                        warn!("Number translator for {source:?} has 0 bits");
                    }
                    match spacer {
                        Some((0,s)) if s!="" => warn!("Number spacer has unused value {s:?}");
                        Some((n,s)) if s=="" && n>0 => warn!("Number spacer empty but nonzero");
                        _ => {}
                    }
                }
                TranslatorVariant::Array{sub,len,..} {
                    if sub.width*len > width {
                        return Err("Array translator has insufficient bits to supply all fields")
                    }
                    if sub.width*len < width {
                        warn!("Array translator for {source:?} has unused bits")
                    }

                    sub.validate(source,translators)
                }
                TranslatorVariant::Styled(_,sub) {
                    if sub.width > width {
                        error!("Styled translator for {source:?} has insufficient bits to supply subtranslator");
                    } else if sub.width < width {
                        warn!("Styled translator for {source:?} has unused bits")
                    }

                    sub.validate(source,translators)
                }
                TranslatorVariant::Duplicate(_,sub) {
                    if sub.width > width {
                        error!("Duplicate translator for {source:?} has insufficient bits to supply subtranslator");
                    } else if sub.width < width {
                        warn!("Duplicate translator for {source:?} has unused bits")
                    }

                    sub.validate(source,translators)
                }
                TranslatorVariant::ChangeBits{sub,bits} {
                    let b = bits.validate(width,source);
                    match b {
                        Some(w) if w < sub.width => error!("ChangeBits translator for {source:?} produces insufficient bits for subtranslator")
                        Some(w) if w > sub.width => warn!("ChangeBits translator for {source:?} produces unused bits")
                        Some(w) => {} 
                        None => warn!("ChangeBits translator for {source:?} may produces potentially variable number of bits")
                    }

                    sub.validate(source,translators)
                }
            }
            Ok(())
        }

        match validate2(self, width, source, translators) {
            Err(e) => {
                error!("Critical error in translator for {source}: {e}");
                self = TranslatorVariant::Const(Translation(Some(("{"+e+"}",WSError,ATOMIC)),vec![]));
            }
            Ok(_) => {}
        }
    }
}


impl BitPart {
    /// Validate a BitPart, returning the bitsize if known
    fn validate(&self,inputsize: u32, source: &str) -> Option<u32> {
        match self {
            BitPart::In => Some(inputsize)
            BitPart::Lit(l) => Some(l.len() as u32)
            BitPart::Concat(subs) => {
                match subs.iter().map(|s| s.validate(inputsize,source)).collect::<Option<Vec<u32>>>() {
                    Some(v) => v.iter().sum()
                    None => None
                }
            }
            BitPart::Slice((from,to),sub) => {
                match sub.validate(inputsize,source) {
                    Some(w) if w>=width => {}
                    Some(w) => error!("BitPart Slice in ChangeBits translator for {source:?} has insufficient bits to slice")
                    None => {}
                }
                Some(to-from)
            }
        }
    }
}
