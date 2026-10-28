import assert from "node:assert/strict";
import { test } from "node:test";

import { isValidMrn } from "../lib/luhn.mjs";
import {
  buildDocument,
  generatePatients,
  SCHEMA_VERSION,
} from "../lib/patient.mjs";
import { createRng } from "../lib/prng.mjs";

test("the PRNG is deterministic and stays in [0,1]", () => {
  const a = createRng(123);
  const b = createRng(123);

  for (let i = 0; i < 1000; i += 1) {
    const value = a();
    assert.equal(value, b());
    assert.ok(value >= 0 && value < 1);
  }
});

test("the same seed gives byte-identical output", () => {
  const first = JSON.stringify(buildDocument({ count: 25, seed: 42 }));
  const second = JSON.stringify(buildDocument({ count: 25, seed: 42 }));
  assert.equal(first, second);
});

test("different seeds give different output", () => {
  assert.notDeepEqual(generatePatients(10, 1), generatePatients(10, 2));
});

test("the requested number of patients is returned", () => {
  assert.equal(generatePatients(37, 5).length, 37);
});

test("identities (authority + MRN) are unique", () => {
  const patients = generatePatients(500, 7);
  const identities = new Set(
    patients.map((p) => `${p.assigningAuthority}|${p.mrn}`),
  );
  assert.equal(identities.size, patients.length);
});

test("every MRN has a valid check digit and 8 digits", () => {
  for (const patient of generatePatients(200, 3)) {
    assert.match(patient.mrn, /^\d{8}$/);
    assert.equal(isValidMrn(patient.mrn), true);
  }
});

test("data is synthetic by construction", () => {
  for (const patient of generatePatients(200, 11)) {
    assert.match(patient.assigningAuthority, /^SYNTH-/);
  }
});

test("field have the documented shape", () => {
  for (const patient of generatePatients(200, 13)) {
    assert.match(patient.birthDate, /^\d{4}-\d{2}-\d{2}$/);
    assert.ok(
      patient.birthDate >= "1930-01-01" && patient.birthDate <= "2024-12-31",
    );
    assert.ok(["F", "M", "O", "U"].includes(patient.administrativeSex));
    assert.equal(patient.homeAddress.country, "ZA");
    assert.match(patient.homeAddress.postalCode, /^\d{4}$/);
    assert.equal(patient.active, true);
  }
});

test("the document carries the envelope and schema version", () => {
  const document = buildDocument({ count: 3, seed: 9 });
  assert.equal(document.meta.schemaVersion, SCHEMA_VERSION);
  assert.equal(document.meta.count, 3);
  assert.equal(document.data.length, 3);
});

test("invalid count or seed throws RangeError", () => {
  assert.throws(() => generatePatients(0, 1), RangeError);
  assert.throws(() => generatePatients(10_001, 1), RangeError);
  assert.throws(() => generatePatients(1.5, 1), RangeError);
  assert.throws(() => generatePatients("10", 1), RangeError);
  assert.throws(() => generatePatients(10, -1), RangeError);
});
