import glot_frontend/public/editor/command
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, KeyboardBindingsDraftSelected,
  RunInstructionsBuildCommandsDraftChanged, RunInstructionsModeDraftChanged,
  RunInstructionsRunCommandDraftChanged, SettingsCancelled, SettingsClicked,
  SettingsDialogClosed, SettingsSubmitted,
}
import glot_frontend/public/editor/model.{
  type RealModel, RealModel, RunInstructionsDraft,
}
import glot_frontend/public/editor/run_instructions
import glot_frontend/public/editor/settings as editor_settings
import youid/uuid.{type Uuid}

pub fn update(
  model: RealModel,
  msg: Msg,
  _current_user_id: option.Option(Uuid),
) -> #(RealModel, command.Command(Msg)) {
  case msg {
    SettingsClicked -> #(
      RealModel(
        ..model,
        editor_settings_draft: model.editor_settings,
        run_instructions_mode_draft: run_instructions.run_instructions_mode(
          model,
        ),
        run_instructions_draft: run_instructions.run_instructions_to_draft(
          run_instructions.effective_run_instructions(model),
        ),
      ),
      command.OpenDialog(ids.settings_dialog),
    )

    KeyboardBindingsDraftSelected(bindings) -> #(
      RealModel(
        ..model,
        editor_settings_draft: editor_settings.EditorSettings(
          keyboard_bindings: bindings,
        ),
      ),
      command.none(),
    )

    RunInstructionsModeDraftChanged(value) -> #(
      RealModel(
        ..model,
        run_instructions_mode_draft: run_instructions.run_instructions_mode_from_string(
          value,
        ),
      ),
      command.none(),
    )

    RunInstructionsBuildCommandsDraftChanged(build_commands_text) -> {
      #(
        RealModel(
          ..model,
          run_instructions_draft: RunInstructionsDraft(
            build_commands_text: build_commands_text,
            run_command: model.run_instructions_draft.run_command,
          ),
        ),
        command.none(),
      )
    }

    RunInstructionsRunCommandDraftChanged(run_command) -> {
      #(
        RealModel(
          ..model,
          run_instructions_draft: RunInstructionsDraft(
            build_commands_text: model.run_instructions_draft.build_commands_text,
            run_command: run_command,
          ),
        ),
        command.none(),
      )
    }

    SettingsCancelled -> #(
      RealModel(
        ..model,
        editor_settings_draft: model.editor_settings,
        run_instructions_mode_draft: run_instructions.run_instructions_mode(
          model,
        ),
        run_instructions_draft: run_instructions.run_instructions_to_draft(
          run_instructions.effective_run_instructions(model),
        ),
      ),
      command.CloseDialog(ids.settings_dialog),
    )

    SettingsSubmitted -> {
      let next_model =
        RealModel(
          ..model,
          editor_settings: model.editor_settings_draft,
          run_instructions_override: run_instructions.run_instructions_override_from_draft(
            model,
          ),
        )

      #(
        next_model,
        command.batch([
          command.CloseDialog(ids.settings_dialog),
          command.SaveSettings(model.editor_settings_draft),
          command.SaveDraft(next_model),
        ]),
      )
    }

    SettingsDialogClosed -> #(
      RealModel(
        ..model,
        editor_settings_draft: model.editor_settings,
        run_instructions_mode_draft: run_instructions.run_instructions_mode(
          model,
        ),
        run_instructions_draft: run_instructions.run_instructions_to_draft(
          run_instructions.effective_run_instructions(model),
        ),
      ),
      focus_editor(),
    )
    _ -> #(model, command.none())
  }
}

fn focus_editor() -> command.Command(msg) {
  command.Focus(ids.editor)
}

import gleam/option
