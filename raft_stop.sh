#!/bin/bash
export COMPOSE_PROJECT_NAME=net
docker-compose -f docker-compose-orderer-raft.yaml -f docker-compose-peer.yaml down

docker volume prune
