#!/bin/bash

#shellcheck disable=SC1091
. /usr/bin/utilities.sh

function setup_runtime_configuration() {
  sed "s:__DATA_DIRECTORY__:${DATA_DIRECTORY}:g" "/elasticsearch/config/elasticsearch.yml.template" \
    | sed "s:__CLUSTER_NAME__:${EXPOSE_HOST:-elasticsearch}:g" \
    > "/elasticsearch/config/elasticsearch.yml"

  mkdir -p "$SSL_DIRECTORY"

  local ssl_cert_file="${SSL_DIRECTORY}/server.crt"
  local ssl_key_file="${SSL_DIRECTORY}/server.key"

  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    # Always perfer a certificate defined in the Environment
    # Deploy will always provide it this way
    echo "Cert present in environment - using them"
    echo "$SSL_CERTIFICATE" > "$ssl_cert_file"
    echo "$SSL_KEY" > "$ssl_key_file"
  elif [ -f "$ssl_cert_file" ] && [ -f "$ssl_key_file" ]; then
    # Outside of Deploy, you may provide a certificate from the filesystem
    echo "Cert present on filesystem - using them"
  else
    # If no certificate is provided, generate a self-signed one as last resort
    echo "Cert not found - autogenerating"
    SUBJ="/C=US/ST=New York/L=New York/O=Example/CN=elasticsearch.example.com"
    OPTS="req -nodes -new -x509 -sha256"
    # shellcheck disable=2086
    openssl $OPTS -subj "$SUBJ" -keyout "$ssl_key_file" -out "$ssl_cert_file" 2>/dev/null
  fi

  unset SSL_CERTIFICATE
  unset SSL_KEY

  # ES demands that the certificate and key live in the Elasticsearch config directory
  # Since we prefer the config to NOT be persistent, we'll copy the certificate from
  # the persistent location to the config location every time the container starts
  cp $ssl_key_file $ssl_cert_file /elasticsearch/config/

  chmod 600 "$ssl_key_file"
  chown -R "${ES_USER}:${ES_GROUP}" /elasticsearch/config/
}


if [[ "$#" -eq 0 ]]; then
  setup_runtime_configuration
  exec /usr/bin/cluster-wrapper

elif [[ "$1" == "--readonly" ]]; then
  echo "Not supported"
  exit 1

elif [[ "$1" == "--initialize" ]]; then
  # NOTE: Technically we're not going to use the runtime configuration, but we
  # use setup_runtime_configuration to grab the cert and persist it to disk if
  # it was provided in the environment.
  setup_runtime_configuration

  /elasticsearch/bin/elasticsearch-users useradd "${USERNAME:-aptible}" -pass "$PASSPHRASE" -r superuser

  cp /elasticsearch/config/users $DATA_DIRECTORY
  cp /elasticsearch/config/users_roles $DATA_DIRECTORY

  # WARNING: Don't touch any directory that's not on DATA_DIRECTORY or
  # SSL_DIRECTORY here: your changes wouldn't be persisted from --initialize to
  # runtime.
  es_dirs=("${DATA_DIRECTORY}/data" "${DATA_DIRECTORY}/log" "${DATA_DIRECTORY}/work" "${DATA_DIRECTORY}/scripts")
  mkdir -p "${es_dirs[@]}"
  chown -R "${ES_USER}:${ES_GROUP}" "${es_dirs[@]}"

elif [[ "$1" == "--client" ]]; then
  echo "This image does not support the --client option. Use curl instead." && exit 1

elif [[ "$1" == "--dump" ]]; then
  echo "Not supported"
  exit 1

elif [[ "$1" == "--restore" ]]; then
  echo "Not supported"
  exit 1

elif [[ "$1" == "--discover" ]]; then
  cat <<EOM
{
  "version": "1.0",
  "environment": {
    "PASSPHRASE": "$(pwgen -s 32)"
  }
}
EOM

elif [[ "$1" == "--connection-url" ]]; then
  ES_EXPOSE_PORT_PTR="EXPOSE_PORT_${ES_PORT}"

  cat <<EOM
{
  "version": "1.0",
  "credentials": [
    {
      "type": "elasticsearch",
      "default": true,
      "connection_url": "${ES_PROTOCOL}://${USERNAME:-aptible}:${PASSPHRASE}@${EXPOSE_HOST}:${!ES_EXPOSE_PORT_PTR}"
    }
  ]
}
EOM

else
  echo "Unrecognized command: $1"
  exit 1
fi
