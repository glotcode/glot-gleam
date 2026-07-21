import gleam/option
import glot_core/snippet/snippet_dto
import glot_frontend/public/editor/command
import glot_frontend/public/editor/execution
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{type Msg, SaveFinished}
import glot_frontend/public/editor/model.{type RealModel, RealModel}
import glot_frontend/public/editor/policy
import youid/uuid.{type Uuid}

pub fn save_snippet(
  model: RealModel,
  current_user_id: option.Option(Uuid),
  close_dialog: Bool,
) -> #(RealModel, command.Command(Msg)) {
  let visibility = policy.visibility(model, current_user_id)
  let generation = model.save_generation + 1
  let data =
    snippet_dto.SnippetData(
      title: model.title,
      language: model.language,
      visibility: visibility,
      stdin: stdin_to_string(model.stdin),
      run_instructions: model.run_instructions_override,
      files: model.files,
    )

  let save_command = case policy.save_operation(model, current_user_id) {
    policy.CreateSnippet ->
      command.CreateSnippet(
        snippet_dto.CreateSnippetRequest(data: data),
        fn(result) { SaveFinished(generation, result) },
      )

    policy.UpdateSnippet(slug) ->
      command.UpdateSnippet(
        snippet_dto.UpdateSnippetRequest(slug: slug, data: data),
        fn(result) { SaveFinished(generation, result) },
      )
  }

  let combined_command = case close_dialog {
    True -> command.batch([command.CloseDialog(ids.save_dialog), save_command])
    False -> save_command
  }

  #(
    RealModel(
      ..model,
      visibility: visibility,
      save_generation: generation,
      save_state: execution.Saving,
    ),
    combined_command,
  )
}

fn stdin_to_string(stdin: option.Option(String)) -> String {
  case stdin {
    option.Some(content) -> content
    option.None -> ""
  }
}
