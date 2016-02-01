#!/bin/bash
set -o errexit
set -o pipefail


. /usr/bin/utilities.sh


# File name constants
ES_CLUSTER_NAME_FILE="${DATA_DIRECTORY}/cluster-name"
ES_CLUSTER_HOSTS_FILE="${DATA_DIRECTORY}/cluster-hosts"


sed "s:SSL_DIRECTORY:${SSL_DIRECTORY}:g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

function elastic_initialize_conf_dir () {
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

  # TODO - Fix this (!).
  #NODE_PUBLISH_HOST="192.168.99.101"
  #NODE_PUBLISH_PORT="1234"

  es_config="/elasticsearch/config/elasticsearch.yml"
  cp "${es_config}"{.template,}

  sed -i "s/__CLUSTER_NAME__/${CLUSTER_NAME}/g"             "${es_config}"
  sed -i "s/__CLUSTER_HOSTS__/${CLUSTER_HOSTS}/g"           "${es_config}"
  sed -i "s/__NODE_PUBLISH_HOST__/${NODE_PUBLISH_HOST}/g"   "${es_config}"
  sed -i "s/__NODE_PUBLISH_PORT__/${NODE_PUBLISH_PORT}/g"   "${es_config}"
}


if [[ "$1" == "--initialize" ]]; then
  # Nginx SSL Setup
  htpasswd -b -c "${DATA_DIRECTORY}/auth_basic.htpasswd" "${USERNAME:-aptible}" "$PASSPHRASE"
  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/server.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/server.key
    chmod og-rwx "$SSL_DIRECTORY"/server.key
  fi

  # TODO - Run ES as separate user to prevent access to SSL certs.

  # Discover cluster name, load up master host.
  echo "Initializing cluster name"
  CLUSTER_NAME="es-$(pwgen -s 10)"
  echo "${CLUSTER_NAME}" > "${ES_CLUSTER_NAME_FILE}"

elif [[ "$1" == "--activate-leader" ]]; then
  # TODO - Document that this *needs* to have access to the master volumes.
  # Export htaccess for slave to replicate.
  echo "ELASTIC_REPLICATION_HTACCESS='$(cat "${DATA_DIRECTORY}/auth_basic.htpasswd")'"

elif [[ "$1" == "--initialize-from" ]]; then
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --initialize-from https://..." && exit

  echo "${ELASTIC_REPLICATION_HTACCESS}" > "${DATA_DIRECTORY}/auth_basic.htpasswd"

  # Get the cluster name and nodes, store them
  # https://www.elastic.co/guide/en/elasticsearch/reference/1.5/cluster-nodes-info.html
  # TODO - Do we want to keep --insecure here?
  es_settings="$(curl --insecure --silent "${2}/_nodes" | extract_es_settings.py)"
  eval "$es_settings"

  echo "${CLUSTER_NAME}" > "${DATA_DIRECTORY}/cluster-name"
  echo "${CLUSTER_HOSTS}" > "${DATA_DIRECTORY}/cluster-hosts" # TODO - Do we need to update this periodically to register new hosts?

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

elif [[ "$1" == "--readonly" ]]; then
  elastic_initialize_conf_dir
  READONLY=1 /usr/sbin/nginx-wrapper

else
  elastic_initialize_conf_dir
  /usr/sbin/nginx-wrapper

fi
