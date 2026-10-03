# patient-registry-api
A **synthetic patient registry domain**, written as an ObjectScript package that later sprints put behind a REST API and a gateway

## Domain

`PatientRegistry.Patient` is persistent; its case-sensitive identity is
`(AssigningAuthority, MRN)`, enforced by a unique composite index. MRNs are
strings so leading zeroes survive. `PatientRegistry.Address` is a serial object
stored inside its patient, not a separate persistent record.

JSON uses `assigningAuthority`, `mrn`, `givenName`, `familyName`, and `address`
(`line1`, `city`, `postalCode`, `country`). Both identity fields are required
nonempty strings. Names and address fields, when supplied, must be strings.
Import/export uses `%DynamicObject`; `ToJSON().%ToJSON()` produces JSON text.

```objectscript
set data=##class(%DynamicObject).%FromJSON("{""assigningAuthority"":""SYNTHETIC"",""mrn"":""000000018"",""givenName"":""Synthetic""}")
set sc=##class(PatientRegistry.Patient).MergeSafeUpdate(data,.id)
if $system.Status.IsError(sc) do $system.Status.DisplayError(sc)
set patient=##class(PatientRegistry.Patient).%OpenId(id)
write patient.ToJSON().%ToJSON()
```

`FromJSON(data,.patient)` constructs an unsaved object. `MergeSafeUpdate`
creates or updates by identity, preserves omitted fields (including nested
address fields), and clears the address only for explicit JSON `null`.
It acquires `LOCK +^PatientRegistry.Lock(authority,mrn):timeout` (default five
seconds) before its host-variable SQL lookup, refreshes cached objects, and
saves inside `TSTART`/`TCOMMIT`, with `TROLLBACK` and lock release on failure.
It returns `%Status` and an ID only on success. Call it **outside any active
transaction**; all concurrent registry writers must use this entry point to
honor the merge lock. Direct `%Save()` still enforces identity uniqueness.
An empty serial address exports as JSON `null` (`%SerialObject` getters
automatically instantiate an empty object, so absence is checked with `%IsNull()`).

`PatientRegistry.Patient.CheckDigit(payload)` runs Embedded Python and returns
the Luhn digit to append to a nonempty ASCII-digit payload. The standalone
`python/mrn.py` exposes the same `check_digit` algorithm and `is_valid`.
Check digits are a helper, not a restriction on external authorities' MRNs.

## Fixtures and tests

Generate only synthetic data (no real patient information):

```bash
mkdir -p fixtures
node scripts/generate-fixtures.js 25 > fixtures/patients.json
python -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q
```

The generator accepts 1–10,000 patients, produces deterministic distinct MRNs
with valid Luhn digits, and writes a JSON array to stdout.

Run the IRIS integration tests with Docker:

```bash
docker build -t patient-registry:test .
bash ci/run-iris-tests.sh
```

The container uses IRIS Community 2026.1 with Embedded Python support. Override
the base image with `docker build --build-arg IRIS_IMAGE=<image> ...` if needed.
Community images have time-limited licenses; use a current release when an
older image's license expires.
The test runner creates `REGISTRYTEST` in a **fresh disposable container**,
using its initially empty USER database, imports/compiles the UDL, and runs
`%UnitTest`. It propagates compilation/test failures to the shell and removes
the container. Do not run the CI driver against an existing patient database:
tests clear the patient extent.

GitHub Actions performs the container build, namespace creation, UDL import,
compilation, `%UnitTest`, and then pytest (which also exercises the Node
generator). IRIS tests cover uniqueness, JSON round trips, partial merges,
cached-object refresh, rollback, lock timeout, literal SQL host variables,
invalid input, transaction boundaries, and Embedded Python.
