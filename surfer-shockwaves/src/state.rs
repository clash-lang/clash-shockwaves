//! Module defining the state of the plugin.

use crate::cache::*;
use crate::config::*;
use crate::data::*;

/// The state of the plugin (loaded data and configurations, cache)
#[derive(Debug)]
pub struct State {
    pub data: Data,
    pub config: Config,
    pub cache: Cache,
}

impl State {
    pub fn new() -> Self {
        Self {
            data: Data::new(),
            config: Config::default(),
            cache: Cache::default(),
        }
    }

    /// Store the new translation metadata and reset the cache.
    pub fn set_data(&mut self, data: Data) {
        self.data = data;
        self.cache = Cache::default();
    }
}
