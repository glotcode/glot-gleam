import glot_backend/logging/api_log/model/entry as api_log_entry
import glot_backend/logging/page_log/model/entry as page_log_entry
import glot_backend/logging/pageview/model/entry as pageview_entry

pub type Entry {
  Api(api_log_entry.Entry)
  Page(page_log_entry.Entry)
  Pageview(pageview_entry.Entry)
}
