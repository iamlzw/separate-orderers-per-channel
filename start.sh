#!/bin/bash
export COMPOSE_PROJECT_NAME=net
#export FABRIC_CFG_PATH=/home/www/go/src/github.com/hyperledger/fabric-samples/config/
docker-compose -f docker-compose-orderer.yaml -f docker-compose-peer.yaml up -d
