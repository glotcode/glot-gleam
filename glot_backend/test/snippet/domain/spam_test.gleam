import gleam/option
import glot_core/language
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_core/snippet/snippet_spam
import glot_core/validation_error

pub fn snippet_spam_filter_allows_normal_code_test() {
  assert snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Hello world",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(name: "main.py", content: "print(\"hello\")"),
        ],
      ),
    )
    == Ok(Nil)
}

pub fn snippet_spam_filter_blocks_obvious_spam_test() {
  let result =
    snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Earn money fast",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(
            name: "promo.txt",
            content: "Contact me on Telegram https://t.me/spam_now click here",
          ),
        ],
      ),
    )

  let assert Error(validation_error.SpamDetected(message)) = result
  assert message != ""
}
