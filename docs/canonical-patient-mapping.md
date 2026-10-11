# Canonical Patient — mapping specification v1 (draft)

**INTEGRATION FOCUS — canonical model.** When many systems exchange patients, every pair of systems translating directly produces _N×(N−1)_ mappings. A canonical model reduces it to _N_ mappings (each system ↔ canonical). This table is the seed of that model; `assigningAuthority` + `mrn` is its identity,

Canonical format = the JSON objects in `fixtures/generated/patients.json` (`{ data, meta }` envelope).
Every transformation of a patient between representations is defined here **before** it is coded.

| Canonical JSON           | `Patient` property       | HL7 v2 (future, S3) | FHIR R4 (future, S5)         | Notes                                |
| ------------------------ | ------------------------ | ------------------- | ---------------------------- | ------------------------------------ |
| `assigningAuthority`     | `AssigningAuthority`     | PID-3.4 (CX.4)      | `Patient.identifier.system`  | Identity part 1                      |
| `mrn`                    | `MRN`                    | PID-3.1 (CX.1)      | `Patient.identifier.value`   | Identity part 2                      |
| `familyName`             | `FamilyName`             | PID-5.1             | `Patient.name.family`        | Stored as given, never "corrected"   |
| `givenName`              | `GivenName`              | PID-5.2             | `Patient.name.given`         |                                      |
| `birthDate`              | `BirthDate`              | PID-7 (`yyyyMMdd`)  | `Patient.birthDate`          | Canonical = ISO 8601 date            |
| `administrativeSex`      | `AdministrativeSex`      | PID-8               | `Patient.gender`             | F→female, M→male, O→other, U→unknown |
| `homeAddress.line1`      | `HomeAddress.Line1`      | PID-11.1            | `Patient.address.line[0]`    |                                      |
| `homeAddress.line2`      | `HomeAddress.Line2`      | PID-11.2            | `Patient.address.line[1]`    |                                      |
| `homeAddress.city`       | `HomeAddress.City`       | PID-11.3            | `Patient.address.city`       |                                      |
| `homeAddress.region`     | `HomeAddress.Region`     | PID-11.4            | `Patient.address.state`      |                                      |
| `homeAddress.postalCode` | `HomeAddress.PostalCode` | PID-11.5            | `Patient.address.postalCode` |                                      |
| `homeAddress.country`    | `HomeAddress.Country`    | PID-11.6            | `Patient.address.country`    | ISO 3166-1 alpha-2                   |
| `active`                 | `Active`                 | —                   | `Patient.active`             | Soft-delete flag                     |

Dates are ISO 8601 (`YYYY-MM-DD`); timestamps (from Night 4) are ISO 8601 UTC with `Z`.
`meta.schemaVersion` must equal `Patient` parameter `SCHEMAVERSION` (`1.0.0`).
