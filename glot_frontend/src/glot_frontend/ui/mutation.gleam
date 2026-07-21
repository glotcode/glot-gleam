import gleam/option

pub type MutationState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub fn clear_feedback(state: MutationState) -> MutationState {
  case state {
    Saving -> Saving
    Idle | Saved | SaveError(_) -> Idle
  }
}

pub fn is_saving(state: MutationState) -> Bool {
  case state {
    Saving -> True
    Idle | Saved | SaveError(_) -> False
  }
}

pub fn error(state: MutationState) -> option.Option(String) {
  case state {
    SaveError(message) -> option.Some(message)
    Idle | Saving | Saved -> option.None
  }
}
