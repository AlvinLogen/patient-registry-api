#!/usr/bin/env bash
set -euo pipefail

image="${1:-patient-registry:test}"
container="$(docker run -d "$image")"
cleanup() {
    if [ "$?" -ne 0 ]; then
        docker logs "$container"
    fi
    docker rm -f "$container" >/dev/null
}
trap cleanup EXIT

ready=false
for attempt in {1..60}; do
    if [ "$(docker inspect --format '{{.State.Running}}' "$container")" != true ]; then
        echo "IRIS container exited during startup" >&2
        exit 1
    fi
    if docker exec "$container" iris qlist | grep -q 'running'; then
        ready=true
        break
    fi
    sleep 2
done
if [ "$ready" != true ]; then
    echo "IRIS did not start within 120 seconds" >&2
    exit 1
fi

docker exec -i "$container" iris session IRIS -U %SYS <<'OBJECTSCRIPT'
set sc=$system.OBJ.Load("/opt/patient-registry/ci/RunTests.cls","ck")
if $system.Status.IsError(sc) do $system.Status.DisplayError(sc) do $system.Process.Terminate(,1)
set sc=##class(PatientRegistry.CI.RunTests).Run()
if $system.Status.IsError(sc) do $system.Status.DisplayError(sc) do $system.Process.Terminate(,1)
halt
OBJECTSCRIPT
