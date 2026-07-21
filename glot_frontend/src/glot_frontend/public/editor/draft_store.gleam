import gleam/option
import glot_core/language
import glot_frontend/platform/clock
import glot_frontend/platform/local_storage
import glot_frontend/public/editor/draft
import glot_frontend/public/editor/draft_persistence
import glot_frontend/public/editor/draft_repository
import lustre/effect.{type Effect}

pub fn load_new_snippet(
  language_slug: String,
) -> option.Option(draft.StoredEditorDraft) {
  draft_repository.load(
    draft_persistence.NewSnippet(language_slug),
    using: production_storage(),
  )
}

pub fn save_new_snippet(
  language: language.Language,
  value: draft.EditorDraft,
) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    let _ =
      draft_repository.save(
        draft_persistence.NewSnippet(language.to_string(language)),
        value,
        using: production_storage(),
      )
    Nil
  })
}

pub fn clear_new_snippet(language: language.Language) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    let _ =
      draft_repository.clear(
        draft_persistence.NewSnippet(language.to_string(language)),
        using: production_storage(),
      )
    Nil
  })
}

pub fn load_existing_snippet(
  slug: String,
) -> option.Option(draft.StoredEditorDraft) {
  draft_repository.load(
    draft_persistence.ExistingSnippet(slug),
    using: production_storage(),
  )
}

pub fn save_existing_snippet(
  slug: String,
  value: draft.EditorDraft,
) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    let _ =
      draft_repository.save(
        draft_persistence.ExistingSnippet(slug),
        value,
        using: production_storage(),
      )
    Nil
  })
}

pub fn clear_existing_snippet(slug: String) -> Effect(msg) {
  effect.from(fn(_dispatch) {
    let _ =
      draft_repository.clear(
        draft_persistence.ExistingSnippet(slug),
        using: production_storage(),
      )
    Nil
  })
}

fn production_storage() -> draft_repository.Storage {
  draft_repository.Storage(
    read: local_storage.get,
    write: local_storage.set,
    remove: local_storage.remove,
    now_milliseconds: clock.now_milliseconds,
  )
}
