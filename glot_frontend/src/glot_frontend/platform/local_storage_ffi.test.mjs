import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import { getItem, removeItem, setItem } from "./local_storage_ffi.mjs";

afterEach(() => {
  delete globalThis.window;
});

test("storage operations are safe during server rendering", () => {
  assert.deepEqual(getItem("key"), [false, ""]);
  assert.equal(setItem("key", "value"), false);
  assert.equal(removeItem("key"), false);
});

test("storage operations preserve empty values and missing items", () => {
  const values = new Map();
  globalThis.window = {
    localStorage: {
      getItem: key => values.has(key) ? values.get(key) : null,
      setItem: (key, value) => values.set(key, value),
      removeItem: key => values.delete(key),
    },
  };

  assert.equal(setItem("empty", ""), true);
  assert.deepEqual(getItem("empty"), [true, ""]);
  assert.deepEqual(getItem("missing"), [false, ""]);
  assert.equal(removeItem("empty"), true);
  assert.deepEqual(getItem("empty"), [false, ""]);
});

test("browser storage security errors are contained", () => {
  globalThis.window = {};
  Object.defineProperty(globalThis.window, "localStorage", {
    get() {
      throw new Error("blocked");
    },
  });

  assert.deepEqual(getItem("key"), [false, ""]);
  assert.equal(setItem("key", "value"), false);
  assert.equal(removeItem("key"), false);
});
