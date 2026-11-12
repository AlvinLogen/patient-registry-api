# Performance baseline — patient registry (S1)

**Environment:** CPU / RAM / Docker Desktop version / IRIS image tag (and digest) / date:
**Data:** 10,000 synthetic patients (`--seed 7`). **Method:** `$ZHOROLOG` in an `iris session`; first run discarded; median of three.

| Measurement                              | Result (median of 3) | Notes                  |
| ---------------------------------------- | -------------------- | ---------------------- |
| Import 10,000 patients, one transaction  | \_\_\_ s             | all indices maintained |
| Identity lookup via `IdentifierIdx` x500 | \_\_\_ s             |                        |
| Same lookup by MRN only (full scan) x500 | \_\_\_ s             |                        |
| Ratio (scan / index)                     | \_\_\_ x             |                        |

## What this does and does not show

- Shows: the order-of-magnitude benefit of the unique composite index on the hottest query.
- Does not show: behaviour under concurrency, a network hop, TLS, or a REST layer. Those are measured with k6 in S6.
- Not a requirement: no threshold is asserted here. If a threshold becomes a requirement, it becomes a test.
