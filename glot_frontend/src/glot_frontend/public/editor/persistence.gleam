import gleam/option
import glot_frontend/public/editor/draft
import glot_frontend/public/editor/draft_store
import glot_frontend/public/editor/model.{type RealModel}
import lustre/effect.{type Effect}

pub fn from_model(model: RealModel) -> draft.EditorDraft {
  draft.EditorDraft(
    title: model.title,
    language: model.language,
    files: model.files,
    stdin: model.stdin,
    run_instructions_override: model.run_instructions_override,
  )
}

pub fn save(model: RealModel) -> Effect(msg) {
  case model.slug {
    option.None ->
      draft_store.save_new_snippet(model.language, from_model(model))
    option.Some(slug) ->
      draft_store.save_existing_snippet(slug, from_model(model))
  }
}

pub fn clear(model: RealModel) -> Effect(msg) {
  case model.slug {
    option.None -> draft_store.clear_new_snippet(model.language)
    option.Some(slug) -> draft_store.clear_existing_snippet(slug)
  }
}
