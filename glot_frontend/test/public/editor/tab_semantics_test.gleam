import gleam/option
import glot_frontend/public/editor/model
import glot_frontend/public/editor/tab_semantics

pub fn arrow_keys_cycle_through_editor_tabs_test() {
  let tabs = [model.FileTab(0), model.FileTab(1), model.StdinTab]

  assert tab_semantics.keyboard_destination(
      tabs,
      model.FileTab(0),
      "ArrowRight",
    )
    == option.Some(model.FileTab(1))
  assert tab_semantics.keyboard_destination(tabs, model.StdinTab, "ArrowRight")
    == option.Some(model.FileTab(0))
  assert tab_semantics.keyboard_destination(tabs, model.FileTab(0), "ArrowLeft")
    == option.Some(model.StdinTab)
}

pub fn home_and_end_keys_select_boundary_tabs_test() {
  let tabs = [model.FileTab(0), model.FileTab(1), model.StdinTab]

  assert tab_semantics.keyboard_destination(tabs, model.FileTab(1), "Home")
    == option.Some(model.FileTab(0))
  assert tab_semantics.keyboard_destination(tabs, model.FileTab(1), "End")
    == option.Some(model.StdinTab)
  assert tab_semantics.keyboard_destination(tabs, model.FileTab(1), "Enter")
    == option.None
}
