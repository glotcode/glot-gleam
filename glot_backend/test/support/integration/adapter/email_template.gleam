import glot_backend/email/ports/template_store
import support/integration/adapter/state
import support/integration/adapter/unexpected
import support/integration/store/email

pub fn defaults() -> template_store.TemplateStore {
  template_store.TemplateStore(
    list: fn() { unexpected.query("email_template.list") },
    get: fn(_) { unexpected.query("email_template.get") },
    update: fn(_) { unexpected.command("email_template.update") },
  )
}

pub fn new(test_state: state.State) -> template_store.TemplateStore {
  template_store.TemplateStore(
    list: fn() { Ok(email.list_email_templates(state.get(test_state))) },
    get: fn(name) {
      Ok(email.find_email_template_by_name(state.get(test_state), name))
    },
    update: fn(template) {
      state.update(test_state, fn(db) {
        email.update_email_template(db, template)
      })
      Ok(Nil)
    },
  )
}
