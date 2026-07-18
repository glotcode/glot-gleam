export type ThemePreference = "system" | "light" | "dark";

export const themeCookieName: "glot_theme";

export function readThemeCookie(cookieHeader: string): ThemePreference;

export function serializeThemeCookie(
  preference: ThemePreference,
  secure: boolean,
): string;
