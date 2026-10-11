import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { test } from "node:test";

import { isValidMrn, luhnCheckDigit } from "../lib/luhn.mjs";

const vectors = JSON.parse(
  await readFile(
    new URL("../../../fixtures/vectors/mrn-check-digit.json", import.meta.url),
    "utf-8",
  ),
);

test("check digits match the shared vectors", () => {
  for (const { payload, checkDigit } of vectors.valid) {
    assert.equal(luhnCheckDigit(payload), checkDigit, `payload ${payload}`);
    assert.equal(
      isValidMrn(payload + checkDigit),
      true,
      `mrn for payload ${payload}`,
    );
  }
});

test("invalid MRNs from the shared vectors are rejected", () => {
  for (const mrn of vectors.invalidMrns) {
    assert.equal(isValidMrn(mrn), false, `mrn ${JSON.stringify(mrn)}`);
  }
});

test("non-ASCII and malformed payloads throw RangeError", () => {
  for (const bad of ["", "12a4", "12 4", "\u0661\u0662\u0663"]) {
    assert.throws(() => luhnCheckDigit(bad), RangeError);
  }
});
