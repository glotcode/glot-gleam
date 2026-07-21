import gleeunit
import glot_frontend/admin/config/section
import glot_frontend/ui/mutation

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn edits_are_resettable_and_saved_atomically_test() {
  let initial = section.init(#("old", False))
  let loaded = section.loaded(initial, #("old", False))
  let edited = section.edit(loaded, fn(_) { #("new", True) })

  assert section.is_dirty(edited)
  assert section.reset(edited).draft == #("old", False)

  let saved = section.saved(section.begin_save(edited), edited.draft)
  assert !section.is_dirty(saved)
  assert saved.saved == #("new", True)
  assert saved.mutation_state == mutation.Saved
}

pub fn load_and_save_failures_remain_independent_test() {
  let model = section.init(0)
  let load_failed = section.load_failed(section.begin_load(model), "load")
  let save_failed = section.save_failed(load_failed, "save")

  assert save_failed.load_state == section.LoadError("load")
  assert save_failed.mutation_state == mutation.SaveError("save")
}
