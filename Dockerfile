ARG IRIS_IMAGE=intersystemsdc/iris-community:2026.1
FROM ${IRIS_IMAGE}

COPY --chown=irisowner:irisowner src /opt/patient-registry/src
COPY --chown=irisowner:irisowner tests/iris /opt/patient-registry/tests/iris
COPY --chown=irisowner:irisowner ci /opt/patient-registry/ci

ENTRYPOINT ["/iris-main"]
CMD ["--check-caps", "false", "--ISCAgent", "false"]
