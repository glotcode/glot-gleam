import glot_frontend/public/login/command
import glot_frontend/public/login/ports
import lustre/effect.{type Effect}

pub fn run(
  command: command.Command(msg),
  using ports: ports.Ports(msg),
) -> Effect(msg) {
  case command {
    command.None -> effect.none()
    command.DetectPasskeySupport(complete) ->
      ports.detect_passkey_support(complete)
    command.SendLoginToken(email, complete) ->
      ports.send_login_token(email, complete)
    command.Login(email, token, complete) -> ports.login(email, token, complete)
    command.BeginPasskeyLogin(complete) -> ports.begin_passkey_login(complete)
    command.AuthenticatePasskey(options, complete) ->
      ports.authenticate_passkey(options, complete)
    command.FinishPasskeyLogin(request, complete) ->
      ports.finish_passkey_login(request, complete)
    command.NavigateReplace(path) -> ports.navigate_replace(path)
  }
}
