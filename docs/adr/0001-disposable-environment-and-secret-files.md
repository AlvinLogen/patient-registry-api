# ADR-P1-0001 — Disposable IRIS environment with secrets as mounted files

**Status:** Accepted · **Date:** 2026-11-11 · **Issue:** #6
**Related:** architecture-repository principles P1 (Git is the source of truth), P4 (protect data), P6 (disposable environments)

## Context

The registry runs in an IRIS Community container on a developer machine and on CI runners. Both must be
rebuildable from Git alone, and no credential may enter Git, an image layer, or a process environment.

## Options considered

A. Durable `%SYS` volume with passwords supplied as environment variables.
B. Disposable container (no volume) with passwords supplied as read-only Docker secret files.
C. Durable volume with secret files.

## Decision

We will run a **disposable** container (Option B): the namespace, role, user and grants are created by scripts
from Git, and passwords are mounted as read-only secret files (`iris_admin_password`, `iris_app_password`).

## Consequences

- Positive: development and CI use the same Compose file and scripts; no secret in `docker inspect`, logs
  or images; every environment is clean, so a green CI run is real evidence.
- Negative: all data is lost on `docker compose down -v`; acceptable only while data is synthetic and
  regenerable from `fixtures/`. Storage definitions must be exported to Git before data matters.
- Negative: Docker Desktop is not an officially supported platform for InterSystems images; the Linux CI runner
  is the authority.

## Revisit triggers

Non-regenerable data exists; an upgrade must be rehearsed on retained data; a shared (non-disposable)
environment is introduced.
