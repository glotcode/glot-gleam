import assert from "node:assert/strict";
import test from "node:test";

import {
  cookieNoticeStorageKey,
  forgetNotice,
  noticeWasSeen,
  rememberNotice,
} from "./glot-cookie-notice-preference.mjs";

function storage() {
  const values = new Map();
  return {
    getItem: (key) => values.get(key) ?? null,
    removeItem: (key) => values.delete(key),
    setItem: (key, value) => values.set(key, value),
  };
}

test("remembers and forgets that the cookie notice was seen", () => {
  const localStorage = storage();

  assert.equal(noticeWasSeen(localStorage), false);
  rememberNotice(localStorage);
  assert.equal(localStorage.getItem(cookieNoticeStorageKey), "true");
  assert.equal(noticeWasSeen(localStorage), true);
  forgetNotice(localStorage);
  assert.equal(noticeWasSeen(localStorage), false);
});

test("storage errors leave the notice available", () => {
  const blockedStorage = {
    getItem: () => {
      throw new Error("blocked");
    },
    removeItem: () => {
      throw new Error("blocked");
    },
    setItem: () => {
      throw new Error("blocked");
    },
  };

  assert.equal(noticeWasSeen(blockedStorage), false);
  assert.doesNotThrow(() => rememberNotice(blockedStorage));
  assert.doesNotThrow(() => forgetNotice(blockedStorage));
});
