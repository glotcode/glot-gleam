import gleam/option
import glot_frontend/admin/config/section
import glot_frontend/admin/ui/form as admin_form
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

import glot_frontend/admin/config/passkey.{
  type Model, type Msg, ChallengeTimeoutSecondsChanged, OriginChanged,
  ResetClicked, RpIdChanged, SaveClicked,
}
import glot_frontend/admin/config/section_view

pub fn view(model: Model) -> Element(Msg) {
  let dirty = section.is_dirty(model)
  section_view.card(
    title: "Passkey",
    subtitle: "Controls the WebAuthn relying party identity and challenge lifetime used for passkey registration and login.",
    state: model.mutation_state,
    dirty:,
    idle_badge: option.None,
    fields: html.div([attribute.class("admin-page__field-grid")], [
      admin_form.text_input(
        label: "Origin",
        help: "Fully qualified site origin used for WebAuthn challenges. Example: https://glot.io",
        value: model.draft.origin,
        placeholder: "",
        on_input: OriginChanged,
      ),
      admin_form.text_input(
        label: "RP ID",
        help: "WebAuthn relying party ID, usually the registrable domain.",
        value: model.draft.rp_id,
        placeholder: "",
        on_input: RpIdChanged,
      ),
      admin_form.text_input(
        label: "Challenge timeout",
        help: "Seconds before a passkey challenge expires.",
        value: model.draft.challenge_timeout_seconds,
        placeholder: "",
        on_input: ChallengeTimeoutSecondsChanged,
      ),
    ]),
    footer: section_view.footer(
      load_state: model.load_state,
      mutation_state: model.mutation_state,
      dirty:,
      idle_message: option.None,
      reset_msg: ResetClicked,
      save_msg: SaveClicked,
    ),
  )
}
