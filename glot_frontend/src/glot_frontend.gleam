import glot_frontend/editor_page
import glot_frontend/home_page
import glot_frontend/login_page
import glot_frontend/route
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import modem

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Flags)

  Nil
}

type Model {
  Model(route: route.Route, page_model: PageModel)
}

type PageModel {
  HomePageModel(home_page.Model)
  LoginPage(login_page.Model)
  EditorPage(editor_page.Model)
  EmptyPageModel
}

fn init_page(route: route.Route) -> #(PageModel, Effect(Msg)) {
  case route {
    route.Home -> {
      let #(m, eff) = home_page.init()
      #(HomePageModel(m), effect.map(eff, HomePageMsg))
    }

    route.Login -> {
      let #(m, eff) = login_page.init()
      #(LoginPage(m), effect.map(eff, LoginPageMsg))
    }

    route.NewSnippet(language) -> {
      let #(m, eff) = editor_page.init(language)
      #(EditorPage(m), effect.map(eff, EditorPageMsg))
    }

    route.NotFound(_) -> #(EmptyPageModel, effect.none())
  }
}

type Flags {
  Flags
}

fn init(_flags: Flags) -> #(Model, Effect(Msg)) {
  let r = case modem.initial_uri() {
    Ok(uri) -> route.from_uri(uri)
    Error(_) -> route.Home
  }

  let #(page_model, page_effect) = init_page(r)

  let eff =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> UserNavigatedTo
    })

  let effects = effect.batch([eff, page_effect])

  #(Model(route: r, page_model: page_model), effects)
}

type Msg {
  UserNavigatedTo(route: route.Route)
  HomePageMsg(home_page.Msg)
  LoginPageMsg(login_page.Msg)
  EditorPageMsg(editor_page.Msg)
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg, model.page_model {
    HomePageMsg(page_msg), HomePageModel(page_model) -> {
      let #(new_page_model, page_effect) =
        home_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: HomePageModel(new_page_model))
      #(new_model, effect.map(page_effect, HomePageMsg))
    }

    LoginPageMsg(page_msg), LoginPage(page_model) -> {
      let #(new_page_model, page_effect) =
        login_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: LoginPage(new_page_model))
      #(new_model, effect.map(page_effect, LoginPageMsg))
    }

    EditorPageMsg(page_msg), EditorPage(page_model) -> {
      let #(new_page_model, page_effect) =
        editor_page.update(page_model, page_msg)
      let new_model = Model(..model, page_model: EditorPage(new_page_model))
      #(new_model, effect.map(page_effect, EditorPageMsg))
    }

    UserNavigatedTo(route:), _ -> {
      let #(page_model, page_effect) = init_page(route)
      #(Model(route:, page_model:), page_effect)
    }

    _, _ -> {
      #(model, effect.none())
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  case model.page_model {
    EmptyPageModel -> {
      not_found_view()
    }

    HomePageModel(page_model) -> {
      let elem = home_page.view(page_model)
      element.map(elem, HomePageMsg)
    }

    LoginPage(page_model) -> {
      let elem = login_page.view(page_model)
      element.map(elem, LoginPageMsg)
    }

    EditorPage(page_model) -> {
      let elem = editor_page.view(page_model)
      element.map(elem, EditorPageMsg)
    }
  }
}

fn not_found_view() -> Element(Msg) {
  html.div([], [
    html.h2([], [html.text("404 Not Found")]),
  ])
}
