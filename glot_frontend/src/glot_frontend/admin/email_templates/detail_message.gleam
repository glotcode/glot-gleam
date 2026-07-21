import glot_core/admin/email_template_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  TemplateLoaded(
    api_response.Response(email_template_dto.GetEmailTemplateResponse),
  )
  SubjectChanged(String)
  TextBodyChanged(String)
  HtmlBodyChanged(String)
  ResetClicked
  SaveClicked
  SaveFinished(
    Generation,
    api_response.Response(email_template_dto.UpdateEmailTemplateResponse),
  )
}
