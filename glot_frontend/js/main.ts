import { applyThemePreference } from "./custom_elements/glot-theme-picker";

applyThemePreference();

const isAdminRoute =
  window.location.pathname === "/admin" ||
  window.location.pathname.startsWith("/admin/");

if (isAdminRoute) {
  void import("./admin");
} else {
  void import("./public");
}
