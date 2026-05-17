import gleam/int
import gleam/list
import gleam/option
import gleam/string
import glot_core/language
import glot_core/snippet/snippet_dto.{type SnippetData}
import glot_core/snippet/snippet_model.{type File}
import glot_core/validation_error

const block_threshold = 12

pub type Signal {
  Signal(reason: String, score: Int)
}

pub fn ensure_clean(
  data: SnippetData,
) -> Result(Nil, validation_error.ValidationError) {
  let signals = payload_signals(data)
  let score = total_score(signals)

  case score >= block_threshold {
    True -> Error(validation_error.SpamDetected(block_message(score, signals)))
    False -> Ok(Nil)
  }
}

fn payload_signals(data: SnippetData) -> List(Signal) {
  let top_level = [
    score_text("title", data.title),
    score_text("stdin", data.stdin),
    score_run_instructions(data.run_instructions),
  ]

  list.fold(data.files, top_level, fn(acc, file) {
    list.append(acc, file_signals(file))
  })
}

fn score_run_instructions(
  run_instructions: option.Option(language.RunInstructions),
) -> Signal {
  case run_instructions {
    option.None -> Signal("", 0)
    option.Some(instructions) -> {
      let commands =
        string.join(
          [instructions.run_command, ..instructions.build_commands],
          with: " ",
        )

      score_text("run_instructions", commands)
    }
  }
}

fn file_signals(file: File) -> List(Signal) {
  [
    score_text("file_name", file.name),
    score_text("file_content", file.content),
    score_file(file),
  ]
}

fn score_file(file: File) -> Signal {
  let normalized_name = normalize(file.name)
  let normalized_content = normalize(file.content)
  let has_spammy_name =
    count_occurrences(normalized_name, "seo") > 0
    || count_occurrences(normalized_name, "casino") > 0
    || count_occurrences(normalized_name, "loan") > 0
    || count_occurrences(normalized_name, "telegram") > 0

  let url_count = url_count(normalized_name) + url_count(normalized_content)

  case has_spammy_name && url_count > 0 {
    True -> Signal("suspicious filename combined with links", 6)
    False -> Signal("", 0)
  }
}

fn score_text(field: String, text: String) -> Signal {
  let normalized = normalize(text)

  let url_signal = case url_count(normalized) >= 2 {
    True -> Signal(field <> " contains multiple links", 6)
    False -> Signal("", 0)
  }

  let contact_signal =
    weighted_phrase_signal(field, normalized, [
      #("telegram", 6),
      #("whatsapp", 6),
      #("discord.gg", 6),
      #("contact me", 6),
      #("dm me", 5),
      #("reach me", 5),
    ])

  let promo_signal =
    weighted_phrase_signal(field, normalized, [
      #("click here", 4),
      #("limited offer", 4),
      #("guaranteed", 4),
      #("earn money", 5),
      #("work from home", 5),
      #("buy now", 5),
      #("seo", 4),
      #("backlinks", 4),
      #("casino", 5),
      #("betting", 5),
      #("loan", 5),
      #("forex", 5),
      #("viagra", 6),
      #("adult", 6),
      #("onlyfans", 6),
    ])

  let obfuscation_signal = case has_zero_width_chars(text) {
    True -> Signal(field <> " contains hidden characters", 8)
    False -> Signal("", 0)
  }

  strongest_signal([
    url_signal,
    contact_signal,
    promo_signal,
    obfuscation_signal,
  ])
}

fn weighted_phrase_signal(
  field: String,
  text: String,
  phrases: List(#(String, Int)),
) -> Signal {
  let matched =
    list.filter(phrases, fn(entry) {
      let #(phrase, _) = entry
      count_occurrences(text, phrase) > 0
    })

  let score =
    list.fold(matched, 0, fn(acc, entry) {
      let #(_, weight) = entry
      acc + weight
    })

  let reasons =
    matched
    |> list.map(fn(entry) {
      let #(phrase, _) = entry
      phrase
    })

  case score > 0 {
    True ->
      Signal(
        field <> " matched spam phrases: " <> string.join(reasons, with: ", "),
        score,
      )
    False -> Signal("", 0)
  }
}

fn strongest_signal(signals: List(Signal)) -> Signal {
  list.fold(signals, Signal("", 0), fn(acc, signal) {
    case signal.score > acc.score {
      True -> signal
      False -> acc
    }
  })
}

fn total_score(signals: List(Signal)) -> Int {
  signals
  |> list.filter(fn(signal) { signal.score > 0 })
  |> list.fold(0, fn(acc, signal) { acc + signal.score })
}

fn block_message(score: Int, signals: List(Signal)) -> String {
  let reasons =
    signals
    |> list.filter(fn(signal) { signal.score > 0 })
    |> list.map(fn(signal) {
      signal.reason <> " (" <> int.to_string(signal.score) <> ")"
    })

  "Snippet was blocked by spam filter. Score: "
  <> int.to_string(score)
  <> ". Signals: "
  <> string.join(reasons, with: "; ")
}

fn normalize(text: String) -> String {
  text
  |> string.trim
  |> string.lowercase
}

fn url_count(text: String) -> Int {
  count_occurrences(text, "http://")
  + count_occurrences(text, "https://")
  + count_occurrences(text, "www.")
  + count_occurrences(text, "t.me/")
  + count_occurrences(text, "discord.gg/")
}

fn count_occurrences(text: String, needle: String) -> Int {
  case string.split(text, needle) {
    [] -> 0
    parts -> list.length(parts) - 1
  }
}

fn has_zero_width_chars(text: String) -> Bool {
  count_occurrences(text, "\u{200B}") > 0
  || count_occurrences(text, "\u{200C}") > 0
  || count_occurrences(text, "\u{200D}") > 0
  || count_occurrences(text, "\u{FEFF}") > 0
}
