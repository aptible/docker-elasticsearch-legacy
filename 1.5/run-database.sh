#!/bin/bash
set -o errexit
set -o pipefail


. /usr/bin/utilities.sh


# Environment variables that might be provided by the environmen

: ${PUBLISH_HOST:=""}       # Host this container's ports may be published on.
: ${PUBLISH_PORT_9300:=""}  # Port this container's port 9300 may be published on.
: ${PUBLISH_PORT_443:=""}   # Similar to above.

# File name constants
ES_CLUSTER_NAME_FILE="${DATA_DIRECTORY}/cluster-name"
ES_CLUSTER_HOSTS_FILE="${DATA_DIRECTORY}/cluster-hosts"


function elastic_runtime_conf () {
  # Load cluster name
  if [[ -f "${ES_CLUSTER_NAME_FILE}" ]]; then
    CLUSTER_NAME="$(cat "${ES_CLUSTER_NAME_FILE}")"
  else
    CLUSTER_NAME="elasticsearch"  # Old default (no cluster name)
  fi

  if [[ -f "${ES_CLUSTER_HOSTS_FILE}" ]]; then
    CLUSTER_HOSTS="$(cat "${ES_CLUSTER_HOSTS_FILE}")"
  else
    CLUSTER_HOSTS="[]"  # No hosts
  fi

  es_config="/elasticsearch/config/elasticsearch.yml"
  cp "${es_config}"{.template,}

  sed -i "s/__CLUSTER_NAME__/${CLUSTER_NAME}/g"   "${es_config}"
  sed -i "s/__CLUSTER_HOSTS__/${CLUSTER_HOSTS}/g" "${es_config}"


  # If we have a publish host, write it in the config file. Otherwise,
  # remove that section altogether. Same for port.

  if [[ -n "${PUBLISH_HOST}"  ]]; then
    sed -i "s/__NODE_PUBLISH_HOST__/${PUBLISH_HOST}/g" "${es_config}"
  else
    sed -i "/__NODE_PUBLISH_HOST__/d" "${es_config}"
  fi

  if [[ -n "${PUBLISH_PORT_9300}"  ]]; then
    sed -i "s/__NODE_PUBLISH_PORT__/${PUBLISH_PORT_9300}/g" "${es_config}"
  else
    sed -i "/__NODE_PUBLISH_PORT__/d" "${es_config}"
  fi
}


function nginx_runtime_conf () {
  sed "s:__SSL_DIRECTORY__:${SSL_DIRECTORY}:g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf
}


function nginx_init_htpasswd () {
  local user="$1"
  local pass="$2"

  htpasswd -b -c "${DATA_DIRECTORY}/auth_basic.htpasswd" "$user" "$pass"
}


function nginx_init_certs () {
  # TODO - Run ES as separate user to prevent access to SSL certs.
  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/server.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/server.key
    chmod og-rwx "$SSL_DIRECTORY"/server.key
  fi
}


if [[ "$1" == "--initialize" ]]; then
  set -o xtrace
  nginx_init_htpasswd "${USERNAME:-aptible}" "$PASSPHRASE"
  nginx_init_certs

  CLUSTER_NAME="es-$(pwgen -s 10)"
  echo "${CLUSTER_NAME}" > "${ES_CLUSTER_NAME_FILE}"

elif [[ "$1" == "--initialize-from" ]]; then
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --initialize-from https://..." && exit 1
  set -o xtrace

  # Parse out username and password
  parse_url "$2"

  nginx_init_htpasswd "$user" "$password"
  nginx_init_certs

  # Fetch cluster settings from master - ${2} is probably /-terminated, so we might end
  # up with a // in here, but that's fine - better safe than sorry.
  es_settings="$(curl --insecure --silent "${2}/_nodes" | extract_es_settings.py)"
  eval "$es_settings"

  echo "${CLUSTER_NAME}" > "${DATA_DIRECTORY}/cluster-name"
  echo "${CLUSTER_HOSTS}" > "${DATA_DIRECTORY}/cluster-hosts"

elif [[ "$1" == "--client" ]]; then
  echo "This image does not support the --client option. Use curl instead." && exit 1

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --dump https://... > dump.es" && exit
  parse_url "$2"
  elasticdump --all=true --input=${protocol:-https}"://"$user":"$password"@"$host":"${port:-80}"" --output=$

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/elasticsearch --restore https://... < dump.es" && exit
  parse_url "$2"
  elasticdump --bulk=true --input=$ --output=${protocol:-https}"://"$user":"$password"@"$host":"${port:-80}""

elif [[ "$1" == "--info" ]]; then
  if [[ -z "$USERNAME" ]] || [[ -z "$PASSPHRASE" ]] || [[ -z "$PUBLISH_HOST" ]] || [[ -z "$PUBLISH_PORT_443" ]]; then
    echo "One of PUBLISH_HOST, USERNAME, PASSPHRASE, PUBLISH_PORT_443 is missing from the environment"
    exit 1
  fi
  echo "CONNECTION_URL=https://${USERNAME}:${PASSPHRASE}@${PUBLISH_HOST}:${PUBLISH_PORT_443}/"

elif [[ "$1" == "--readonly" ]]; then
  elastic_runtime_conf
  nginx_runtime_conf
  READONLY=1 /usr/sbin/nginx-wrapper

else
  elastic_runtime_conf
  nginx_runtime_conf
  /usr/sbin/nginx-wrapper

fi
