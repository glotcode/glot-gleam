import gleam/option
import glot_core/run
import glot_core/snippet/snippet_dto
import glot_frontend/api/response
import glot_frontend/public/editor/draft
import glot_frontend/public/editor/model.{type RealModel}
import glot_frontend/public/editor/settings

pub type Command(msg) {
  None
  Batch(List(Command(msg)))
  LoadEnvironment(fn(String, settings.EditorSettings) -> msg)
  LoadNewDraft(String, fn(option.Option(draft.StoredEditorDraft)) -> msg)
  GetSnippet(
    snippet_dto.GetSnippetRequest,
    fn(response.Response(snippet_dto.SnippetResponse)) -> msg,
  )
  RunCode(run.RunRequest, fn(response.Response(run.RunResult)) -> msg)
  GetLanguageVersion(
    run.GetLanguageVersionRequest,
    fn(response.Response(run.RunResult)) -> msg,
  )
  CreateSnippet(
    snippet_dto.CreateSnippetRequest,
    fn(response.Response(snippet_dto.SnippetResponse)) -> msg,
  )
  UpdateSnippet(
    snippet_dto.UpdateSnippetRequest,
    fn(response.Response(snippet_dto.SnippetResponse)) -> msg,
  )
  LoadExistingDraft(String, fn(option.Option(draft.StoredEditorDraft)) -> msg)
  SaveDraft(RealModel)
  ClearDraft(RealModel)
  ClearExistingDraft(String)
  SaveSettings(settings.EditorSettings)
  OpenDialog(String)
  OpenDialogNextFrame(String)
  CloseDialog(String)
  Focus(String)
  Navigate(String)
  Schedule(Int, msg)
}

pub fn none() -> Command(msg) {
  None
}

pub fn batch(commands: List(Command(msg))) -> Command(msg) {
  Batch(commands)
}
