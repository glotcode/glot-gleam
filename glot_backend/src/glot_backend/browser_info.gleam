import gleam/option.{type Option}
import gleam/string
import glot_core/auth/platform_model

pub type BrowserInfo {
  BrowserInfo(
    os_name: Option(platform_model.OperatingSystem),
    browser_name: Option(platform_model.Browser),
  )
}

const max_user_agent_length = 2000

pub fn from_user_agent(user_agent: Option(String)) -> BrowserInfo {
  case user_agent {
    option.Some(value) ->
      BrowserInfo(
        os_name: detect_os_name(value),
        browser_name: detect_browser_name(value),
      )
    option.None -> BrowserInfo(os_name: option.None, browser_name: option.None)
  }
}

fn detect_os_name(
  user_agent: String,
) -> Option(platform_model.OperatingSystem) {
  cond([
    #(
      contains(user_agent, "iPhone") || contains(user_agent, "iPad"),
      platform_model.IOS,
    ),
    #(contains(user_agent, "Android"), platform_model.Android),
    #(
      contains(user_agent, "Mac OS X") || contains(user_agent, "Macintosh"),
      platform_model.MacOS,
    ),
    #(contains(user_agent, "Windows"), platform_model.Windows),
    #(contains(user_agent, "FreeBSD"), platform_model.FreeBSD),
    #(contains(user_agent, "Linux"), platform_model.Linux),
    #(contains(user_agent, "CrOS"), platform_model.ChromeOS),
  ])
}

fn detect_browser_name(
  user_agent: String,
) -> Option(platform_model.Browser) {
  cond([
    #(contains(user_agent, "Edg/"), platform_model.Edge),
    #(
      contains(user_agent, "OPR/") || contains(user_agent, "Opera/"),
      platform_model.Opera,
    ),
    #(contains(user_agent, "Firefox/"), platform_model.Firefox),
    #(
      contains(user_agent, "Chrome/")
      && !contains(user_agent, "Edg/")
      && !contains(user_agent, "OPR/"),
      platform_model.Chrome,
    ),
    #(
      contains(user_agent, "Safari/")
      && contains(user_agent, "Version/")
      && !contains(user_agent, "Chrome/")
      && !contains(user_agent, "Chromium/")
      && !contains(user_agent, "CriOS/")
      && !contains(user_agent, "FxiOS/")
      && !contains(user_agent, "EdgiOS/"),
      platform_model.Safari,
    ),
  ])
}

fn contains(text: String, pattern: String) -> Bool {
  string.contains(text, pattern)
}

pub fn truncate_user_agent(user_agent: Option(String)) -> Option(String) {
  option.map(user_agent, fn(value) {
    string.slice(value, 0, max_user_agent_length)
  })
}

fn cond(cases: List(#(Bool, a))) -> Option(a) {
  case cases {
    [] -> option.None
    [#(True, value), ..] -> option.Some(value)
    [#(False, _), ..rest] -> cond(rest)
  }
}
