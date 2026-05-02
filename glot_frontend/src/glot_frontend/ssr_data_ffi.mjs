export function take() {
  if (typeof document === "undefined") {
    return "";
  }

  const app = document.getElementById("app");
  if (!app) {
    return "";
  }

  const value = app.getAttribute("data-ssr") ?? "";
  if (value !== "") {
    app.removeAttribute("data-ssr");
  }

  return value;
}
