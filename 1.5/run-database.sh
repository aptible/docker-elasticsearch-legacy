#!/bin/bash
set -o errexit
set -o pipefail


. /usr/bin/utilities.sh

sed "s:SSL_DIRECTORY:${SSL_DIRECTORY}:g" /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf


function elastic_initialize_conf_dir () {
  # Load cluster name
  if [[ -f "${DATA_DIRECTORY}/cluster-name" ]]; then
    CLUSTER_NAME="$(cat "${DATA_DIRECTORY}/cluster-name")"
  else
    CLUSTER_NAME="elasticsearch"  # Old default
  fi

  if [[ -f "${DATA_DIRECTORY}/cluster-hosts" ]]; then
    CLUSTER_HOSTS="$(cat "${DATA_DIRECTORY}/cluster-hosts")"
  else
    CLUSTER_HOSTS="[]"  # No hosts
  fi

  # TODO - Fix this (!).
  #NODE_PUBLISH_HOST="192.168.99.101"
  #NODE_PUBLISH_PORT="1234"
  set -o nounset  # TODO

  es_config="/elasticsearch/config/elasticsearch.yml"
  cp "${es_config}"{.template,}

  sed -i "s/__CLUSTER_NAME__/${CLUSTER_NAME}/g"             "${es_config}"
  sed -i "s/__CLUSTER_HOSTS__/${CLUSTER_HOSTS}/g"           "${es_config}"
  sed -i "s/__NODE_PUBLISH_HOST__/${NODE_PUBLISH_HOST}/g"   "${es_config}"
  sed -i "s/__NODE_PUBLISH_PORT__/${NODE_PUBLISH_PORT}/g"   "${es_config}"
}


if [[ "$1" == "--initialize" ]]; then

  # Nginx SSL Setup
  htpasswd -b -c "$DATA_DIRECTORY"/auth_basic.htpasswd "${USERNAME:-aptible}" "$PASSPHRASE"
  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "$SSL_CERTIFICATE" > "$SSL_DIRECTORY"/server.crt
    echo "$SSL_KEY" > "$SSL_DIRECTORY"/server.key
    chmod og-rwx "$SSL_DIRECTORY"/server.key
  fi

  # Discover cluster name, load up master host.
  # TODO - Should we hit the master and find out about other hosts instead?
  echo "Initializing cluster name"
  CLUSTER_NAME="es-$(pwgen -s 10)"
  echo "${CLUSTER_NAME}" > "${DATA_DIRECTORY}/cluster-name"

elif [[ "$1" == "--initialize-from" ]]; then
  set -o xtrace
  [ -z "$2" ] && echo "docker run aptible/elasticsearch --initialize-from https://..." && exit
  #parse_url "$2"

  # Get the cluster name and nodes, store them
  # https://www.elastic.co/guide/en/elasticsearch/reference/1.5/cluster-nodes-info.html
  eval $(curl -s "${2}/_nodes" | extract_es_settings.py)

  echo "${CLUSTER_NAME}" > "${DATA_DIRECTORY}/cluster-name"
  echo "${CLUSTER_HOSTS}" > "${DATA_DIRECTORY}/cluster-hosts" # TODO - Update periodically?

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
  READONLY=1 /usr/sbin/nginx-wrapper

else
  elastic_initialize_conf_dir
  /usr/sbin/nginx-wrapper

fi
