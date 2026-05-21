import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}

pub type OperatingSystem {
  IOS
  Android
  MacOS
  Windows
  FreeBSD
  Linux
  ChromeOS
}

pub type Browser {
  Safari
  Chrome
  Firefox
  Edge
  Opera
}

pub fn operating_system_to_string(os: OperatingSystem) -> String {
  case os {
    IOS -> "ios"
    Android -> "android"
    MacOS -> "macos"
    Windows -> "windows"
    FreeBSD -> "freebsd"
    Linux -> "linux"
    ChromeOS -> "chromeos"
  }
}

pub fn browser_to_string(browser: Browser) -> String {
  case browser {
    Safari -> "safari"
    Chrome -> "chrome"
    Firefox -> "firefox"
    Edge -> "edge"
    Opera -> "opera"
  }
}

pub fn operating_system_from_string(value: String) -> Option(OperatingSystem) {
  case value {
    "ios" -> option.Some(IOS)
    "android" -> option.Some(Android)
    "macos" -> option.Some(MacOS)
    "windows" -> option.Some(Windows)
    "freebsd" -> option.Some(FreeBSD)
    "linux" -> option.Some(Linux)
    "chromeos" -> option.Some(ChromeOS)
    _ -> option.None
  }
}

pub fn browser_from_string(value: String) -> Option(Browser) {
  case value {
    "safari" -> option.Some(Safari)
    "chrome" -> option.Some(Chrome)
    "firefox" -> option.Some(Firefox)
    "edge" -> option.Some(Edge)
    "opera" -> option.Some(Opera)
    _ -> option.None
  }
}

pub fn encode_operating_system(os: OperatingSystem) -> json.Json {
  json.string(operating_system_to_string(os))
}

pub fn encode_browser(browser: Browser) -> json.Json {
  json.string(browser_to_string(browser))
}

pub fn operating_system_decoder() -> decode.Decoder(OperatingSystem) {
  decode.then(decode.string, fn(value) {
    case operating_system_from_string(value) {
      option.Some(os) -> decode.success(os)
      option.None -> decode.failure(MacOS, "OperatingSystem")
    }
  })
}

pub fn browser_decoder() -> decode.Decoder(Browser) {
  decode.then(decode.string, fn(value) {
    case browser_from_string(value) {
      option.Some(browser) -> decode.success(browser)
      option.None -> decode.failure(Chrome, "Browser")
    }
  })
}

pub fn operating_system_label(os: OperatingSystem) -> String {
  case os {
    IOS -> "iOS"
    Android -> "Android"
    MacOS -> "MacOS"
    Windows -> "Windows"
    FreeBSD -> "FreeBSD"
    Linux -> "Linux"
    ChromeOS -> "ChromeOS"
  }
}

pub fn browser_label(browser: Browser) -> String {
  case browser {
    Safari -> "Safari"
    Chrome -> "Chrome"
    Firefox -> "Firefox"
    Edge -> "Edge"
    Opera -> "Opera"
  }
}
