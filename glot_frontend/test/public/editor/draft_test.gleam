import gleeunit
import glot_frontend/public/editor/draft

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn drafts_expire_only_after_the_retention_window_test() {
  let day_ms = 86_400_000

  assert !draft.is_expired(1000, 1000 + day_ms)
  assert draft.is_expired(1000, 1000 + day_ms + 1)
  assert !draft.is_expired(2000, 1000)
}
