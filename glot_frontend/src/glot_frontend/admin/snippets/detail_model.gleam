import gleam/option
import glot_core/admin/snippet_dto
import glot_core/loadable
import glot_frontend/admin/request_generation.{type Generation}

pub type Model {
  Model(
    slug: String,
    snippet: loadable.Loadable(snippet_dto.SnippetDetailResponse),
    pending_delete: option.Option(snippet_dto.SnippetDetailResponse),
    delete_state: DeleteState,
    delete_generation: Generation,
  )
}

pub type DeleteState {
  DeleteIdle
  Deleting
}
