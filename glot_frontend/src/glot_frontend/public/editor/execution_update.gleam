import gleam/list
import gleam/option
import glot_core/api_action
import glot_core/language
import glot_core/public_action
import glot_core/run
import glot_frontend/api/response as api_response
import glot_frontend/public/editor/command
import glot_frontend/public/editor/document
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/file_workflow
import glot_frontend/public/editor/message.{
  type Msg, RunFinished, RunSubmitted, SourceCodeChanged, TabKeyPressed,
  TabSelected, VersionRunFinished,
}
import glot_frontend/public/editor/model.{
  type EditorTab, type RealModel, RealModel,
}
import glot_frontend/public/editor/run_instructions
import glot_frontend/public/editor/tab_semantics
import youid/uuid.{type Uuid}

pub fn update(
  model: RealModel,
  msg: Msg,
  _current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    TabSelected(tab) -> #(select_tab(model, tab), command.none())

    TabKeyPressed(current, key) -> {
      let tabs = editor_tabs(model)
      case tab_semantics.keyboard_destination(tabs, current, key) {
        option.Some(tab) -> #(
          select_tab(model, tab),
          command.Focus(tab_semantics.tab_id(tab)),
        )
        option.None -> #(model, command.none())
      }
    }

    SourceCodeChanged(source_code, revision) -> {
      let next_model =
        file_workflow.update_selected_tab_content(model, source_code)
        |> fn(model) { RealModel(..model, editor_revision: revision) }
      #(next_model, command.SaveDraft(next_model))
    }

    RunSubmitted -> {
      let generation = model.run_generation + 1
      let request =
        run.RunRequest(
          image: language.container_image(model.language),
          payload: run.RunRequestPayload(
            run_instructions: run_instructions.effective_run_instructions(model),
            files: model.files,
            stdin: model.stdin,
          ),
        )

      #(
        RealModel(
          ..model,
          run_generation: generation,
          run_state: execution.Running,
          // A new run becomes the active console operation. Without clearing
          // completed save feedback, "Saved" masks the eventual run output.
          save_state: execution.SaveIdle,
        ),
        command.RunCode(request, fn(result) { RunFinished(generation, result) }),
      )
    }

    RunFinished(generation, _) if generation != model.run_generation -> #(
      model,
      command.none(),
    )

    RunFinished(_, result) -> {
      case result {
        api_response.Success(run_result) -> #(
          RealModel(..model, run_state: execution.Completed(run_result)),
          command.none(),
        )

        api_response.ApiFailure(error) -> #(
          RealModel(
            ..model,
            run_state: execution.RequestError(api_response.error_message(error)),
          ),
          command.none(),
        )

        api_response.HttpFailure(_) -> #(
          RealModel(
            ..model,
            run_state: execution.RequestError(
              "Could not complete "
              <> api_action.to_string(api_action.public(public_action.RunAction))
              <> ".",
            ),
          ),
          command.none(),
        )
      }
    }

    VersionRunFinished(language, _) if language != model.language -> #(
      model,
      command.none(),
    )

    VersionRunFinished(_, result) -> {
      case result {
        api_response.Success(Ok(run.SuccessfulRun(stdout:, ..))) ->
          case stdout == "" {
            True -> #(model, command.none())
            False -> #(
              RealModel(..model, version_info: option.Some(stdout)),
              command.none(),
            )
          }

        _ -> #(model, command.none())
      }
    }

    _ -> #(model, command.none())
  }
}

fn select_tab(model: RealModel, tab: EditorTab) -> RealModel {
  RealModel(
    ..model,
    selected_tab: tab,
    edit_entry_filename: document.default_file_name(model.files, tab),
    editor_external_revision: model.editor_external_revision + 1,
  )
}

fn editor_tabs(model: RealModel) -> List(EditorTab) {
  let file_tabs = file_tabs(list.length(model.files), 0)
  case model.stdin {
    option.Some(_) -> list.append(file_tabs, [model.StdinTab])
    option.None -> file_tabs
  }
}

fn file_tabs(count: Int, index: Int) -> List(EditorTab) {
  case index >= count {
    True -> []
    False -> [model.FileTab(index), ..file_tabs(count, index + 1)]
  }
}
