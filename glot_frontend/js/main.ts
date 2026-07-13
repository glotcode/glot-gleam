const isAdminRoute =
  window.location.pathname === "/admin" ||
  window.location.pathname.startsWith("/admin/");

if (isAdminRoute) {
  void import("./admin");
} else {
  void import("./public");
}
