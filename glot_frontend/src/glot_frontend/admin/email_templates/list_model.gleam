import glot_core/admin/email_template_dto
import glot_core/loadable

pub type Model {
  Model(
    templates: loadable.Loadable(
      List(email_template_dto.EmailTemplateSummaryResponse),
    ),
  )
}
