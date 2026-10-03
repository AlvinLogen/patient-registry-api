#!/usr/bin/env node
'use strict';

function checkDigit(payload) {
  let total = 0;
  [...payload].reverse().forEach((character, index) => {
    let digit = Number(character);
    if (index % 2 === 0) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    total += digit;
  });
  return String((10 - (total % 10)) % 10);
}

const argument = process.argv[2] ?? '10';
const count = Number(argument);
if (process.argv.length > 3 || !/^\d+$/.test(argument) || !Number.isSafeInteger(count) || count < 1 || count > 10000) {
  console.error('Usage: node scripts/generate-fixtures.js [count: 1..10000]');
  process.exit(1);
}

const patients = Array.from({ length: count }, (_, index) => {
  const payload = String(index + 1).padStart(8, '0');
  return {
    assigningAuthority: 'SYNTHETIC',
    mrn: payload + checkDigit(payload),
    givenName: `Synthetic${index + 1}`,
    familyName: 'Patient',
    address: {
      line1: `${index + 1} Example Street`,
      city: 'Example City',
      postalCode: '00000',
      country: 'ZZ',
    },
  };
});
process.stdout.write(`${JSON.stringify(patients, null, 2)}\n`);
