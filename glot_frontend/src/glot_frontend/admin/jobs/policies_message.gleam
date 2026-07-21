import glot_core/admin/job_type_policy_dto
import glot_frontend/admin/jobs/policies_model.{type Field}
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  PoliciesLoaded(
    Generation,
    api_response.Response(job_type_policy_dto.ListJobTypePoliciesResponse),
  )
  FieldChanged(String, Field, String)
  ResetClicked(String)
  SaveClicked(String)
  SaveFinished(
    String,
    Generation,
    api_response.Response(job_type_policy_dto.JobTypePolicyResponse),
  )
}
