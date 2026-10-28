# Canonical Patient — mapping specification v1 (draft)

**INTEGRATION FOCUS — canonical model.** When many systems exchange patients, every pair of systems translating directly produces _N×(N−1)_ mappings. A canonical model reduces it to _N_ mappings (each system ↔ canonical). This table is the seed of that model; `assigningAuthority` + `mrn` is its identity,

Canonical format = the JSON objects in `fixtures/generated/patients.json` (`{ data, meta }` envelope).
Every transformation of a patient between representations is defined here **before** it is coded.

| Canonical JSON           | `Patient` property       | HL7 v2 (future, S3) | FHIR R4 (future, S5)         | Notes                                                      |
| ------------------------ | ------------------------ | ------------------- | ---------------------------- | ---------------------------------------------------------- |
| `assigningAuthority`     | `AssigningAuthority`     | PID-3.4 (CX.4)      | `Patient.identifier.system`  | Identity part 1                                            |
| `mrn`                    | `MRN`                    | PID-3.1 (CX.1)      | `Patient.identifier.value`   | Identity part 2                                            |
| `familyName`             | `FamilyName`             | PID-5.1             | `Patient.name.family`        | Stored as given, never "corrected"                         |
| `givenName`              | `GivenName`              | PID-5.2             | `Patient.name.given`         |                                                            |
| `birthDate`              | `BirthDate`              | PID-7 (`yyyyMMdd`)  | `Patient.birthDate`          | Canonical = ISO 8601 date                                  |
| `administrativeSex`      | `AdministrativeSex`      | PID-8               | `Patient.gender`             | F→female, M→male, O→other, U→unknown                       |
| `homeAddress.line1`      | `HomeAddress.Line1`      | PID-11.1            | `Patient.address.line[0]`    |                                                            |
| `homeAddress.line2`      | `HomeAddress.Line2`      | PID-11.2            | `Patient.address.line[1]`    |                                                            |
| `homeAddress.city`       | `HomeAddress.City`       | PID-11.3            | `Patient.address.city`       |                                                            |
| `homeAddress.region`     | `HomeAddress.Region`     | PID-11.4            | `Patient.address.state`      |                                                            |
| `homeAddress.postalCode` | `HomeAddress.PostalCode` | PID-11.5            | `Patient.address.postalCode` |                                                            |
| `homeAddress.country`    | `HomeAddress.Country`    | PID-11.6            | `Patient.address.country`    | ISO 3166-1 alpha-2                                         |
| `active`                 | `Active`                 | —                   | `Patient.active`             | Soft-delete flag                                           |
| `version`                | `Version`                | —                   | `Patient.meta.versionId`     | Read-only; incremented by `MergeUpdate`; ignored on import |
| `createdAt`              | `CreatedAt`              | —                   | —                            | Read-only; ISO 8601 UTC with `Z`; ignored on import        |
| `updatedAt`              | `UpdatedAt`              | —                   | `Patient.meta.lastUpdated`   | Read-only; ISO 8601 UTC with `Z`; ignored on import        |

Dates are ISO 8601 (`YYYY-MM-DD`); timestamps (from Night 4) are ISO 8601 UTC with `Z`.
`meta.schemaVersion` must equal `Patient` parameter `SCHEMAVERSION` (`1.0.0`).

## Rules (v1)

1. **Strings are strings.** `assigningAuthority`, `mrn`, `familyName`, `givenName` must be JSON _strings_.
   `"mrn": "10000016"` is valid; `"mrn": 10000016` is rejected.
2. **Whitelist, never loop.** Import and update copy only the editable fields: `familyName`, `givenName`,
   `birthDate`, `administrativeSex`, `homeAddress`, `active`. Anything else is ignored.
3. **Identity is immutable.** An update that contains `assigningAuthority` or `mrn` is rejected.
4. **Merge-patch update.** Only the fields present in an update are changed; absent fields are untouched.
5. **Optimistic concurrency.** An update may carry the `version` the caller last read; a mismatch is rejected.
6. **Errors carry a stable code** (below) and never echo field values.

| Code                    | Meaning                                                   | HTTP mapping (S2)       |
| ----------------------- | --------------------------------------------------------- | ----------------------- |
| `PR-INVALID-INPUT`      | Input is malformed or outside the contract                | 400                     |
| `PR-NOT-FOUND`          | No patient with that identity                             | 404                     |
| `PR-VERSION-CONFLICT`   | The caller's version is stale                             | 409                     |
| `PR-IDENTITY-IMMUTABLE` | The update tried to change identity                       | 422                     |
| `PR-LOCK-TIMEOUT`       | Could not obtain the patient lock in time                 | 503 (retry later)       |
| `PR-IMPORT-REJECTED`    | A row of a bulk import was rejected; nothing was imported | 422                     |
| `PR-NESTED-TRANSACTION` | Called inside an open transaction                         | 500 (programming error) |
