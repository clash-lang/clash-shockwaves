//! A cache (for structures).
//! Actual cache usage is found in `structure.rs`.

use std::collections::HashMap;

use crate::data::Structure;

pub type StructureMap = HashMap<String, Structure>;

#[derive(Debug, Default)]
pub struct Cache {
    pub structures: StructureMap,
}
