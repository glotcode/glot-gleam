import glot_frontend/api/response

pub type Msg {
  EmailChanged(String)
  TopicChanged(String)
  MessageChanged(String)
  WebsiteChanged(String)
  SubmittedForm
  SubmissionFinished(response.Response(Nil))
}
