import glot_core/admin/rate_limit_config_dto
import glot_core/public_action
import glot_core/rate_limit
import glot_frontend/admin/rate_limits/model.{type EditorTab}
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  PoliciesLoaded(
    Generation,
    api_response.Response(rate_limit_config_dto.RateLimitPoliciesResponse),
  )
  EditClicked(public_action.PublicAction)
  EditDialogClosed
  TabSelected(public_action.PublicAction, EditorTab)
  FieldChanged(
    public_action.PublicAction,
    EditorTab,
    rate_limit.TimeUnit,
    String,
  )
  CancelClicked
  SaveClicked(public_action.PublicAction)
  SaveFinished(
    public_action.PublicAction,
    Generation,
    api_response.Response(rate_limit_config_dto.RateLimitPolicyResponse),
  )
}
