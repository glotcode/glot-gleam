import gleam/option
import glot_frontend/app/quick_actions
import glot_web/page/top_bar

pub type Msg {
  Opened
  Dismissed
  Closed
  QueryChanged(String)
  KeyPressed(String)
  Submitted
  Reset
}

pub type Command(action) {
  None
  OpenDialog
  CloseDialog
  ScrollTo(Int)
  Run(action)
}

pub fn init() -> quick_actions.Model {
  quick_actions.init()
}

pub fn update(
  model: quick_actions.Model,
  msg: Msg,
  sections: List(top_bar.Section(action)),
) -> #(quick_actions.Model, Command(action)) {
  case msg {
    Opened -> #(quick_actions.reset(model), OpenDialog)
    Dismissed | Closed | Reset -> #(quick_actions.reset(model), CloseDialog)
    QueryChanged(query) -> #(quick_actions.set_query(model, query), None)
    KeyPressed("ArrowDown") -> move(model, sections, 1)
    KeyPressed("ArrowUp") -> move(model, sections, -1)
    KeyPressed("Enter") | Submitted -> run_selected(model, sections)
    KeyPressed(_) -> #(model, None)
  }
}

fn move(
  model: quick_actions.Model,
  sections: List(top_bar.Section(action)),
  delta: Int,
) -> #(quick_actions.Model, Command(action)) {
  let next = quick_actions.move_for_sections(model, sections, delta)
  #(next, ScrollTo(quick_actions.normalized_index_for_sections(next, sections)))
}

fn run_selected(
  model: quick_actions.Model,
  sections: List(top_bar.Section(action)),
) -> #(quick_actions.Model, Command(action)) {
  case quick_actions.selected_action(model, sections) {
    option.Some(top_bar.Action(msg: action, ..)) -> #(
      quick_actions.clear_query(model),
      Run(action),
    )
    option.None -> #(model, None)
  }
}
