import { luhnCheckDigit } from "./luhn.mjs";
import { createRng } from "./prng.mjs";

export const SCHEMA_VERSION = "1.1.0";
const MAX_COUNT = 10000;

const AUTHORITIES = ["SYNTH-HOSP-A", "SYNTH-HOSP-B", "SYNTH-LAB-C"];
const GIVEN = [
  "Alex",
  "Sam",
  "Jordan",
  "Taylor",
  "Morgan",
  "Casey",
  "Riley",
  "Jamie",
  "Robin",
  "Zo\u00eb",
];
const FAMILY = [
  "Testfamily",
  "Samplesurname",
  "Fixtureson",
  "Mockwell",
  "Dummyfield",
  "O'Testington",
  "van der Fixture",
  "Syntheton-Placeholder",
];

const SEX = ["F", "M", "O", "U"];
const PLACES = [
  { city: "Testville", region: "Gauteng" },
  { city: "Mockton", region: "Western Cape" },
  { city: "Sampleburg", region: "KwaZulu-Natal" },
];

const BIRTH_START = Date.UTC(1930, 0, 1);
const BIRTH_END = Date.UTC(2024, 11, 31);
const DAY_MS = 86_400_000;

const pick = (rng, items) => items[Math.floor(rng() * items.length)];
const inBetween = (rng, min, max) => min + Math.floor(rng() * (max - min + 1));

function assertInt(name, value, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new RangeError(
      `${name} must be an integer between ${min} and ${max}`,
    );
  }
}

function isoBirthDate(rng) {
  const days = inBetween(rng, 0, Math.floor(BIRTH_END - BIRTH_START) / DAY_MS);
  return new Date(BIRTH_START + days * DAY_MS).toISOString().slice(0, 10);
}

export function generatePatients(count, seed) {
  assertInt("count", count, 1, MAX_COUNT);
  assertInt("seed", seed, 0, 0xffffffff);

  const rng = createRng(seed);
  const seen = new Set();
  const patients = [];

  while (patients.length < count) {
    const assigningAuthority = pick(rng, AUTHORITIES);
    const payload = String(inBetween(rng, 1_000_000, 9_999_999));
    const mrn = payload + luhnCheckDigit(payload);
    const identity = `${assigningAuthority}|${mrn}`;

    if (seen.has(identity)) continue;
    seen.add(identity);

    const place = pick(rng, PLACES);
    patients.push({
      assigningAuthority,
      mrn,
      familyName: pick(rng, FAMILY),
      givenName: pick(rng, GIVEN),
      birthDate: isoBirthDate(rng),
      administrativeSex: pick(rng, SEX),
      homeAddress: {
        line1: `${inBetween(rng, 1, 999)} Synthetic Road`,
        line2: "",
        city: place.city,
        region: place.region,
        postalCode: String(inBetween(rng, 1, 9999)).padStart(4, "0"),
        country: "ZA",
      },
      active: true,
    });
  }
  return patients;
}

export function buildDocument({ count, seed }) {
  return {
    data: generatePatients(count, seed),
    meta: {
      generator: "patient-fixture-generator",
      schemaVersion: SCHEMA_VERSION,
      seed,
      count,
    },
  };
}
