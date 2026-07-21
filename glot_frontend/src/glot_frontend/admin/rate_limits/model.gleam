import gleam/option
import glot_core/loadable
import glot_core/public_action
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/ui/mutation

pub type Model {
  Model(
    policies: loadable.Loadable(List(PolicyEditor)),
    active_editor: option.Option(ActiveEditor),
    load_generation: Generation,
  )
}

pub type PolicyEditor {
  PolicyEditor(
    action: public_action.PublicAction,
    saved_tabs: PolicyTabs,
    draft_tabs: PolicyTabs,
    state: mutation.MutationState,
    save_generation: Generation,
  )
}

pub type PolicyTabs {
  PolicyTabs(anonymous: LimitFields, free: LimitFields, free_plus: LimitFields)
}

pub type LimitFields {
  LimitFields(second: String, minute: String, hour: String, day: String)
}

pub type ActiveEditor {
  ActiveEditor(action: public_action.PublicAction, tab: EditorTab)
}

pub type EditorTab {
  AnonymousTab
  FreeTab
  FreePlusTab
}
