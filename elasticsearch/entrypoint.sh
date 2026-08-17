#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Generates the CA and node certificate on first start, then hands over to the
# stock Elasticsearch entrypoint.
#
# Roles:
#   server   Elasticsearch itself (default)
#   certs    generate the certificates and exit
#   <other>  executed verbatim, e.g. `bash` or an elasticsearch-* CLI tool
#
# Running the generation here rather than in a separate init container means a
# plain `docker run` of this image is self-sufficient.
# ---------------------------------------------------------------------------
set -euo pipefail

ES_HOME="${ES_HOME:-/usr/share/elasticsearch}"
CERTS_DIR="${ES_HOME}/config/certs"
NODE_NAME="${ES_NODE_NAME:-elasticsearch}"

generate_certs() {
  if [[ -f "${CERTS_DIR}/${NODE_NAME}/${NODE_NAME}.key" ]]; then
    echo "certificates already present in ${CERTS_DIR}, skipping generation"
    return 0
  fi

  if [[ ! -w "${CERTS_DIR}" ]]; then
    echo "error: ${CERTS_DIR} is not writable by uid $(id -u)." >&2
    echo "A volume mounted there must be owned by uid 1000 — see the Dockerfile." >&2
    return 1
  fi

  echo "generating a self-signed CA and node certificate for '${NODE_NAME}'..."
  "${ES_HOME}/bin/elasticsearch-certutil" ca --silent --pem -out "${CERTS_DIR}/ca.zip"
  unzip -q -o "${CERTS_DIR}/ca.zip" -d "${CERTS_DIR}"

  # The SANs cover both sides of the docker network boundary; hostname
  # verification is disabled in the clients anyway.
  "${ES_HOME}/bin/elasticsearch-certutil" cert --silent --pem \
    -out "${CERTS_DIR}/node.zip" \
    --name "${NODE_NAME}" \
    --dns "${NODE_NAME},localhost" \
    --ip 127.0.0.1 \
    --ca-cert "${CERTS_DIR}/ca/ca.crt" \
    --ca-key "${CERTS_DIR}/ca/ca.key"
  unzip -q -o "${CERTS_DIR}/node.zip" -d "${CERTS_DIR}"

  rm -f "${CERTS_DIR}/ca.zip" "${CERTS_DIR}/node.zip"
  chmod 600 "${CERTS_DIR}/${NODE_NAME}/${NODE_NAME}.key" "${CERTS_DIR}/ca/ca.key" || true
  echo "--- certificates ---"
  find "${CERTS_DIR}" -type f
}

case "${1:-server}" in
  server)
    generate_certs
    # eswrapper is the argument the stock entrypoint expects for "run the node".
    exec /usr/local/bin/docker-entrypoint.sh eswrapper
    ;;
  certs)
    generate_certs
    ;;
  *)
    exec "$@"
    ;;
esac
