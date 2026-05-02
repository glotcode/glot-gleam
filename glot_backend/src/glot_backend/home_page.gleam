import glot_core/page/home
import glot_core/page/site_chrome
import glot_core/page/top_bar
import glot_core/route
import lustre/element.{type Element}

pub fn title() -> String {
  "glot.io - code playground"
}

pub fn view() -> Element(Nil) {
  site_chrome.view(
    top_bar_model: initial_top_bar_model(),
    footer_account_route: route.Account,
    content: home.view(),
  )
}

fn initial_top_bar_model() -> top_bar.ViewModel(Nil) {
  top_bar.ViewModel(
    current_user_label: "Account",
    account_route: route.Account,
    search_query: "",
    selected_index: 0,
    open_msg: Nil,
    close_msg: Nil,
    search_changed: fn(_) { Nil },
    keydown: fn(_) { Nil },
    submit_msg: Nil,
    sections: top_bar.initial_home_sections(fn(_) { Nil }),
  )
}
