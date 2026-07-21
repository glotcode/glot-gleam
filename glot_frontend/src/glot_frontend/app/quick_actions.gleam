import gleam/int
import gleam/list
import gleam/option
import glot_web/page/top_bar

pub type Model {
  Model(query: String, selected_index: Int)
}

pub fn init() -> Model {
  Model(query: "", selected_index: 0)
}

pub fn reset(_model: Model) -> Model {
  init()
}

pub fn set_query(_model: Model, query: String) -> Model {
  Model(query:, selected_index: 0)
}

pub fn clear_query(model: Model) -> Model {
  Model(..model, query: "")
}

pub fn select(model: Model, index: Int) -> Model {
  Model(..model, selected_index: index)
}

pub fn normalized_index(model: Model, item_count: Int) -> Int {
  case item_count <= 0 {
    True -> 0
    False -> int.modulo(model.selected_index, item_count) |> result_or_zero
  }
}

pub fn move(model: Model, delta: Int, item_count: Int) -> Model {
  case item_count <= 0 {
    True -> Model(..model, selected_index: 0)
    False -> {
      let raw = model.selected_index + delta
      let wrapped = case int.modulo(raw, item_count) {
        Ok(value) if value < 0 -> value + item_count
        Ok(value) -> value
        Error(_) -> 0
      }
      Model(..model, selected_index: wrapped)
    }
  }
}

pub fn normalized_index_for_sections(
  model: Model,
  sections: List(top_bar.Section(msg)),
) -> Int {
  top_bar.normalized_selected_index(sections, model.selected_index)
}

pub fn selected_action(
  model: Model,
  sections: List(top_bar.Section(msg)),
) -> option.Option(top_bar.Action(msg)) {
  sections
  |> top_bar.flattened_actions
  |> top_bar.action_at(normalized_index_for_sections(model, sections))
}

pub fn move_for_sections(
  model: Model,
  sections: List(top_bar.Section(msg)),
  delta: Int,
) -> Model {
  select(
    model,
    top_bar.wrapped_selected_index(sections, model.selected_index, delta),
  )
}

pub fn map_sections(
  sections: List(top_bar.Section(action)),
  mapper: fn(action) -> msg,
) -> List(top_bar.Section(msg)) {
  list.map(sections, fn(section) {
    let top_bar.Section(title:, actions:) = section
    top_bar.Section(
      title:,
      actions: list.map(actions, fn(action) {
        top_bar.map_action(action, mapper)
      }),
    )
  })
}

fn result_or_zero(value: Result(Int, Nil)) -> Int {
  case value {
    Ok(index) -> index
    Error(_) -> 0
  }
}
