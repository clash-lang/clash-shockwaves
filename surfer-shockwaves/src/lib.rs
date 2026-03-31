//! # Shockwaves Surfer extension
//!
//! This is the Surfer extension for Shockwaves. Shockwaves is a system developed
//! for Clash to display typed waveforms, but is flexible and modular enough to
//! be used for other purposes as well.
//!
//!
//! ## Inner workings
//!
//! The extension has a global state, storing the translation metadata,
//! configuration options, and a cache of structures.
//!
//! When a VCD file is opened, the translator looks for a JSON file with the same
//! base name. If found, this file is parsed to obtain the metadata.
//!
//! On start and when a VCD file is loaded, the extension also looks for a global and
//! local configuration respectively. When a VCD is loaded, any style files listed in
//! these configuration files are re-read, and all defined style variables are listed.
//! Any occurances of these style variables in the metadata are then replaced.
//!
//! When Surfer looks whether a signal can be translated, the signal is looked for
//! in the map of known signals.
//!
//! When Surfer asks for a signal's structure, the signal's type is determined, and
//! the structure of that type is either recovered from cache, or determined from the
//! type's translator.
//!
//! When Surfer translates a value, the type is obtained from the signal, the translator
//! is obtained from the type, and the translator is used to translate the binary data.
//! The translation is then parsed once again to propagate any special styles.
//!
//! The translators produce a translation that has an render value (the text, style and
//! operator precedence of the toplevel signal) and optional subsignals.
//!
//!
//! ### Example
//!
//! In Haskell, we have a datatype
//!
//! ```hs
//! data T = A Bool | B
//! ```
//!
//! It has the binary values `00`, `01` and `1x`.
//!
//! The automatically derived `Waveform` instance creates a translator definition
//! that roughly takes the shape:
//!
//! ```
//! "T":
//!     Sum
//!         Duplicate
//!             Product "A"
//!                 Ref "Bool"
//!         Duplicate
//!             Const "B"
//! ```
//!
//! In the JSON file, this looks like:
//!
//! ```json
//! "<...>:T": {
//!     "w": 2,
//!     "v": {
//!         "S": [
//!             {
//!                 "w": 1,
//!                 "v": {
//!                     "D": [
//!                         "A",
//!                         {
//!                             "w": 1,
//!                             "v" {
//!                                 "P": {
//!                                     "[": "A ",
//!                                     ",": " ",
//!                                     "]": "",
//!                                     "P": 10,
//!                                     "p": 10,
//!                                     "n": [],
//!                                     "t": [
//!                                         [
//!                                             "0",
//!                                             {
//!                                                 "w":1,
//!                                                 "v": {"R":"<...>:Bool"}
//!                                             }
//!                                         ]
//!                                     ]
//!                                 }
//!                             }
//!                         }
//!                     ]
//!                 }
//!             },
//!             {
//!                 "w": 0,
//!                 "v": {
//!                     "D": [
//!                         "B",
//!                         {
//!                             "w": 0,
//!                             "v": {"C":[["B","D",11],[]]}
//!                         }
//!                     ]
//!                 }
//!             }
//!         ]
//!     }
//! }
//! ```
//!
//! This gets parsed into a translator structure:
//!
//! ```
//! Translator(2,TranslatorVariant::Sum(vec![
//!     Translator(1,TranslatorVariant::Duplicate(
//!         "A",
//!         Translator(1,TranslatorVariant::Product{
//!             start: "A ",
//!             sep: " ",
//!             stop: "",
//!             preci: 10,
//!             preco: 10,
//!             labels: vec![],
//!             subs: vec![
//!                 Translator(1,TranslatorVariant::Ref("<...>:Bool"))
//!             ]
//!         })
//!     )),
//!     Translator(0,TranslatorVariant::Duplicate(
//!         "B",
//!         Translator(0,TranslatorVariant::Const(
//!             Translation(
//!                 Some(("B",WaveStyle::Default,ATOMIC)),
//!                 vec![]
//!             )
//!         ))
//!     )),
//! ]));
//! ```
//!
//! This produces the following translations:
//!
//! ```
//! //00
//! Translation(
//!     Some(("A False",WaveStyle::Inherit(0),10)),
//!     vec![
//!         ("A",Translation(
//!             Some(("A False",WaveStyle::Default,10)),
//!             vec![
//!                 ("0",Translation(
//!                     Some(("False",WaveStyle::Default,11)),
//!                     vec![]
//!                 ))
//!             ]
//!         )),
//!         ("B",Translation(
//!             None,
//!             vec![]
//!         ))
//!     ]
//! )
//!
//! //01
//! Translation(
//!     Some(("A True",WaveStyle::Inherit(0),10)),
//!     vec![
//!         ("A",Translation(
//!             Some(("A True",WaveStyle::Default,10)),
//!             vec![
//!                 ("0",Translation(
//!                     Some(("False",WaveStyle::Default,11)),
//!                     vec![]
//!                 ))
//!             ]
//!         )),
//!         ("B",Translation(None,vec![]))
//!     ]
//! )
//!
//! //1x
//! Translation(
//!     Some(("B",WaveStyle::Inherit(0),11)),
//!     vec![
//!         ("A",Translation(
//!             None,
//!             vec![
//!                 ("0",Translation(
//!                     None,
//!                     vec![]
//!                 ))
//!             ]
//!         )),
//!         ("B",Translation(
//!             Some(("B",WaveStyle::Default,11)),
//!             vec![]
//!         ))
//!     ]
//! )
//! ```
//!
//! These are finally turned into the Surfer representation:
//!
//! ```
//! //1x
//! TranslationResult{
//!     val: ValueRepr::String("B"),
//!     kind: ValueKind::Normal,
//!     subfields: vec![
//!         SubFieldTranslationResult{
//!             name: "A",
//!             result: TranslationResult{
//!                 val: ValueRepr::NotPresent,
//!                 kind: ValueKind::Normal,
//!                 subfields: vec![
//!                     SubFieldTranslationResult{
//!                         name: "0",
//!                         result: TranslationResult{
//!                             val: ValueRepr::NotPresent,
//!                             kind: ValueKind::Normal,
//!                             subfields: vec![]
//!                         }
//!                     }
//!                 ]
//!             }
//!         }
//!         SubFieldTranslationResult{
//!             name: "B",
//!             result: TranslationResult{
//!                 val: ValueRepr::String("B"),
//!                 kind: ValueKind::Normal,
//!                 subfields: vec![]
//!             }
//!         }
//!     ]
//! }
//! ```
//!
//!

mod cache;
mod config;
mod convert;
mod data;
mod plugin;
mod state;
mod structure;
mod stylevars;
mod translate;
