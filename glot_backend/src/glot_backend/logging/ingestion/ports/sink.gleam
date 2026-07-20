import glot_backend/logging/api_log/model/entry as api_log_entry
import glot_backend/logging/page_log/model/entry as page_log_entry
import glot_backend/logging/pageview/model/entry as pageview_entry

pub type Sink {
  Sink(
    write_api: fn(api_log_entry.Entry) -> Nil,
    write_page: fn(page_log_entry.Entry) -> Nil,
    write_pageview: fn(pageview_entry.Entry) -> Nil,
    drain: fn() -> Nil,
  )
}
