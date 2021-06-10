# ![](https://gravatar.com/avatar/11d3bc4c3163e3d238d558d5c9d98efe?s=64) aptible/elasticsearch
[![Docker Repository on Quay.io](https://quay.io/repository/aptible/elasticsearch/status)](https://quay.io/repository/aptible/elasticsearch)
[![Build Status](https://travis-ci.org/aptible/docker-elasticsearch.svg?branch=master)](https://travis-ci.org/aptible/docker-elasticsearch)

[![](http://dockeri.co/image/aptible/elasticsearch)](https://registry.hub.docker.com/u/aptible/elasticsearch/)

Elasticsearch on Docker.

This repository hosts only legacy versions of Elasticsearch. For newer versions, please refer to https://github.com/aptible/docker-elasticsearch

## Installation and Usage

    docker pull quay.io/aptible/elasticsearch

This is an image conforming to the [Aptible database specification](https://support.aptible.com/topics/paas/deploy-custom-database/). To run a server for development purposes, execute

    docker create --name data quay.io/aptible/elasticsearch
    docker run --volumes-from data -e USERNAME=aptible -e PASSPHRASE=pass -e DB=db quay.io/aptible/elasticsearch --initialize
    docker run --volumes-from data -P quay.io/aptible/elasticsearch

The first command sets up a data container named `data` which will hold the configuration and data for the database. The second command creates an Elasticsearch instance with a username, passphrase and database name of your choice. The third command starts the database server.

## Available Tags

* `6.8`
* `6.7`(EOL 2020-09-26)
* `6.6`(EOL 2020-07-29)
* `6.5`(EOL 2020-05-14)
* `6.4`(EOL 2020-02-23)
* `6.3`(EOL 2019-12-13)
* `6.2`(EOL 2019-08-06)
* `6.1`(EOL 2019-06-13)
* `6.0`(EOL 2019-05-14)
* `5.6`(EOL 2019-03-11)
* `5.1`(EOL 2018-06-08)
* `5.0`(EOL 2018-04-26)
* `2.4`(EOL 2018-02-28)
* `2.2`(EOL 2017-08-02)
* ~`1.5`(EOL 2016-09-23)~ Deprecated

    (https://www.elastic.co/support/eol)

## Tests

Tests are run as part of the `Dockerfile` build. To execute them separately within a container, run:

    bats test

## Deployment

To push the Docker image to Quay, run the following command:

    make push

## Continuous Integration

Images are built and pushed to Quay and the Docker Hub on push to master in
Travis.

## Copyright and License

MIT License, see [LICENSE](LICENSE.md) for details.

Copyright (c) 2019 [Aptible](https://www.aptible.com), [Frank Macreery](https://github.com/fancyremarker), and contributors.
