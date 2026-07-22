import gleam/option
import gleam/pair
import glot_frontend/api/response as api_response
import glot_frontend/public/editor/command
import glot_frontend/public/editor/draft_update
import glot_frontend/public/editor/execution_update
import glot_frontend/public/editor/file_update
import glot_frontend/public/editor/loading_workflow
import glot_frontend/public/editor/message.{
  type Msg, AddEntryCancelled, AddEntryClicked, AddEntryDialogClosed,
  AddEntryFilenameChanged, AddEntryKindSelected, AddEntrySubmitted,
  EditEntryCancelled, EditEntryDeleted, EditEntryDialogClosed,
  EditEntryFilenameChanged, EditEntrySubmitted, EditMetadataCancelled,
  EditMetadataClicked, EditMetadataDialogClosed, EditMetadataSubmitted,
  EditMetadataVisibilitySelected, EnvironmentLoaded, ExistingDraftLoaded,
  KeyboardBindingsDraftSelected, NewDraftLoaded, RestoreDraftAccepted,
  RestoreDraftClosed, RestoreDraftDeclined, RunFinished,
  RunInstructionsBuildCommandsDraftChanged, RunInstructionsModeDraftChanged,
  RunInstructionsRunCommandDraftChanged, RunSubmitted, SaveCancelled,
  SaveClicked, SaveConfirmed, SaveDialogClosed, SaveFinished,
  SaveVisibilityDraftSelected, SelectedTabActionClicked, SettingsCancelled,
  SettingsClicked, SettingsDialogClosed, SettingsSubmitted, SnippetInfoClicked,
  SnippetInfoClosed, SnippetInfoDismissed, SnippetLoaded,
  SnippetLoadingDelayElapsed, SourceCodeChanged, TabKeyPressed, TabSelected,
  TitleDraftChanged, VersionRunFinished,
}
import glot_frontend/public/editor/metadata_update
import glot_frontend/public/editor/model.{
  type Model, type RealModel, Initializing, LoadError, LoadingSnippet,
  SupportedLanguage, UnsupportedLanguage,
}
import glot_frontend/public/editor/save_update
import glot_frontend/public/editor/settings_update
import glot_frontend/ui/delayed_loading
import youid/uuid.{type Uuid}

pub fn update(
  model: Model,
  msg: Msg,
  current_user_id: option.Option(Uuid),
) -> #(Model, command.Command(Msg)) {
  case model, msg {
    LoadingSnippet(current_slug, settings, _), SnippetLoaded(slug, result) -> {
      case current_slug == slug, result {
        False, _ -> #(model, command.none())
        True, api_response.Success(response) ->
          loading_workflow.existing_model_from_response(response, settings)

        True, api_response.ApiFailure(error) -> #(
          LoadError(api_response.error_message(error)),
          command.none(),
        )

        True, api_response.HttpFailure(_) -> #(
          LoadError("Could not load snippet."),
          command.none(),
        )
      }
    }

    LoadingSnippet(current_slug, settings, loading_indicator),
      SnippetLoadingDelayElapsed(slug, generation)
    ->
      case current_slug == slug {
        True -> #(
          LoadingSnippet(
            current_slug,
            settings,
            delayed_loading.reveal(loading_indicator, generation),
          ),
          command.none(),
        )
        False -> #(model, command.none())
      }

    Initializing(_), _ -> #(model, command.none())
    UnsupportedLanguage(_), _ -> #(model, command.none())
    LoadingSnippet(_, _, _), _ -> #(model, command.none())
    LoadError(_), _ -> #(model, command.none())
    SupportedLanguage(model), _ ->
      update_helper(model, msg, current_user_id)
      |> pair.map_first(SupportedLanguage)
  }
}

pub fn update_helper(
  model: RealModel,
  msg: Msg,
  current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    EnvironmentLoaded(_, _, _)
    | SnippetLoaded(_, _)
    | SnippetLoadingDelayElapsed(_, _) -> #(model, command.none())

    NewDraftLoaded(_, _) | ExistingDraftLoaded(_, _, _) ->
      draft_update.update(model, msg, current_user_id)

    EditMetadataClicked
    | TitleDraftChanged(_)
    | EditMetadataVisibilitySelected(_)
    | EditMetadataCancelled
    | EditMetadataSubmitted
    | EditMetadataDialogClosed ->
      metadata_update.update(model, msg, current_user_id)

    AddEntryClicked
    | AddEntryKindSelected(_)
    | AddEntryFilenameChanged(_)
    | AddEntryCancelled
    | AddEntrySubmitted
    | AddEntryDialogClosed
    | SelectedTabActionClicked
    | EditEntryFilenameChanged(_)
    | EditEntryCancelled
    | EditEntrySubmitted
    | EditEntryDeleted
    | EditEntryDialogClosed -> file_update.update(model, msg, current_user_id)

    SettingsClicked
    | KeyboardBindingsDraftSelected(_)
    | RunInstructionsModeDraftChanged(_)
    | RunInstructionsBuildCommandsDraftChanged(_)
    | RunInstructionsRunCommandDraftChanged(_)
    | SettingsCancelled
    | SettingsSubmitted
    | SettingsDialogClosed ->
      settings_update.update(model, msg, current_user_id)

    SaveClicked
    | SaveVisibilityDraftSelected(_)
    | SaveCancelled
    | SaveDialogClosed
    | RestoreDraftAccepted
    | RestoreDraftDeclined
    | RestoreDraftClosed
    | SnippetInfoClicked
    | SnippetInfoDismissed
    | SnippetInfoClosed
    | SaveConfirmed
    | SaveFinished(_, _) -> save_update.update(model, msg, current_user_id)

    TabSelected(_)
    | TabKeyPressed(_, _)
    | SourceCodeChanged(_, _)
    | RunSubmitted
    | RunFinished(_, _)
    | VersionRunFinished(_, _) ->
      execution_update.update(model, msg, current_user_id)
  }
}
