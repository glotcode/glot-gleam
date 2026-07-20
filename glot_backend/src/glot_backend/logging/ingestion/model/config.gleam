pub type Config {
  Config(flush_interval_ms: Int, max_batch_size: Int, max_buffer_size: Int)
}

pub fn default() -> Config {
  Config(flush_interval_ms: 5000, max_batch_size: 100, max_buffer_size: 1000)
}
