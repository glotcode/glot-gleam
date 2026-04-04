import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/error
import glot_backend/effect/job/job_algebra
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/transaction/transaction_algebra
import glot_backend/effect/user_action/user_action_algebra

pub type Program(a) {
  Pure(a)
  Fail(error.Error)
  Impure(Effect(Program(a)))
}

pub type Effect(next) {
  BasicEffect(basic_algebra.BasicEffect(next))
  EmailEffect(email_algebra.EmailEffect(next))
  JobEffect(job_algebra.JobEffect(next))
  AuthEffect(auth_algebra.AuthEffect(next))
  SnippetEffect(snippet_algebra.SnippetEffect(next))
  DockerRunEffect(docker_run_algebra.DockerRunEffect(next))
  UserActionEffect(user_action_algebra.UserActionEffect(next))
  TransactionEffect(transaction_algebra.TransactionEffect(next))
}
