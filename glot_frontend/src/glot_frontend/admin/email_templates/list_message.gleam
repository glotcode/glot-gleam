import glot_core/admin/email_template_dto
import glot_frontend/api/response as api_response

pub type Msg {
  TemplatesLoaded(
    api_response.Response(email_template_dto.ListEmailTemplatesResponse),
  )
}
