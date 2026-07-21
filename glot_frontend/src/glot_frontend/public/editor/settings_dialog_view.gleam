import gleam/dynamic/decode
import glot_frontend/public/editor/dialog_controls
import glot_frontend/public/editor/ids
import glot_frontend/public/editor/message.{
  type Msg, RunInstructionsBuildCommandsDraftChanged,
  RunInstructionsModeDraftChanged, RunInstructionsRunCommandDraftChanged,
  SettingsCancelled, SettingsDialogClosed, SettingsSubmitted,
}
import glot_frontend/public/editor/model.{
  type RealModel, CustomRunInstructions, DefaultRunInstructions,
}
import glot_frontend/public/editor/settings as editor_settings
import glot_frontend/public/editor/workspace_view
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(model: RealModel) -> Element(Msg) {
  let custom_run_instructions =
    model.run_instructions_mode_draft == CustomRunInstructions

  html.dialog(
    [
      attribute.id(ids.settings_dialog),
      attribute.class("editor-page__dialog"),
      attribute.attribute("aria-label", "Editor settings"),
      event.on("close", decode.success(SettingsDialogClosed)),
    ],
    [
      html.form(
        [
          attribute.class("editor-page__dialog-form"),
          event.on_submit(fn(_) { SettingsSubmitted }),
        ],
        [
          html.h2([attribute.class("editor-page__dialog-label")], [
            html.text("Keyboard bindings"),
          ]),
          html.div(
            [
              attribute.class("editor-page__dialog-panel"),
              attribute.attribute("role", "group"),
              attribute.attribute("aria-label", "Keyboard bindings"),
            ],
            [
              dialog_controls.keyboard_bindings_option(
                "Default",
                "Standard CodeMirror shortcuts.",
                editor_settings.DefaultBindings,
                model.editor_settings_draft.keyboard_bindings,
              ),
              dialog_controls.keyboard_bindings_option(
                "Emacs",
                "Enable Emacs-style editing commands.",
                editor_settings.EmacsBindings,
                model.editor_settings_draft.keyboard_bindings,
              ),
              dialog_controls.keyboard_bindings_option(
                "Vim",
                "Enable modal Vim keybindings.",
                editor_settings.VimBindings,
                model.editor_settings_draft.keyboard_bindings,
              ),
            ],
          ),
          html.div([attribute.class("editor-page__dialog-divider")], []),
          html.div([attribute.class("editor-page__dialog-section")], [
            html.label(
              [
                attribute.for("editor-page-run-instructions-mode"),
                attribute.class("editor-page__dialog-label"),
              ],
              [
                html.text("Run instructions"),
              ],
            ),
            html.div([attribute.class("editor-page__dialog-panel")], [
              html.select(
                [
                  attribute.id("editor-page-run-instructions-mode"),
                  attribute.name("run_instructions_mode"),
                  attribute.class("editor-page__dialog-select"),
                  attribute.value(
                    workspace_view.run_instructions_mode_to_string(
                      model.run_instructions_mode_draft,
                    ),
                  ),
                  event.on_input(RunInstructionsModeDraftChanged),
                ],
                [
                  html.option(
                    [
                      attribute.value("default"),
                      attribute.selected(
                        model.run_instructions_mode_draft
                        == DefaultRunInstructions,
                      ),
                    ],
                    "Default",
                  ),
                  html.option(
                    [
                      attribute.value("custom"),
                      attribute.selected(
                        model.run_instructions_mode_draft
                        == CustomRunInstructions,
                      ),
                    ],
                    "Custom",
                  ),
                ],
              ),
              html.label(
                [
                  attribute.for("editor-page-build-commands-input"),
                  attribute.class("editor-page__dialog-sublabel"),
                ],
                [html.text("Build commands")],
              ),
              html.textarea(
                [
                  attribute.id("editor-page-build-commands-input"),
                  attribute.name("build_commands"),
                  attribute.rows(2),
                  attribute.class(
                    "editor-page__dialog-input editor-page__dialog-input--multiline",
                  ),
                  attribute.disabled(!custom_run_instructions),
                  event.on_input(RunInstructionsBuildCommandsDraftChanged),
                ],
                model.run_instructions_draft.build_commands_text,
              ),
              html.p([attribute.class("editor-page__dialog-helper-text")], [
                html.text(
                  "One build command per line. Leave blank to skip build.",
                ),
              ]),
              html.label(
                [
                  attribute.for("editor-page-run-command-input"),
                  attribute.class("editor-page__dialog-sublabel"),
                ],
                [html.text("Run command")],
              ),
              html.input([
                attribute.id("editor-page-run-command-input"),
                attribute.name("run_command"),
                attribute.type_("text"),
                attribute.value(model.run_instructions_draft.run_command),
                attribute.class("editor-page__dialog-input"),
                attribute.disabled(!custom_run_instructions),
                event.on_input(RunInstructionsRunCommandDraftChanged),
              ]),
            ]),
          ]),
          html.div([attribute.class("editor-page__dialog-actions")], [
            html.button(
              [
                attribute.type_("button"),
                attribute.class(
                  "editor-page__dialog-button editor-page__dialog-button--secondary",
                ),
                event.on_click(SettingsCancelled),
              ],
              [html.text("Cancel")],
            ),
            html.button(
              [
                attribute.type_("submit"),
                attribute.class("editor-page__dialog-button"),
              ],
              [html.text("Apply")],
            ),
          ]),
        ],
      ),
    ],
  )
}
