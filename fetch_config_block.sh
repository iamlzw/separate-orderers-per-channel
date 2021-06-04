#!/bin/sh

if  [ ! -n "$1" ] ;then
    echo "you must set CHANNEL_ID"
    exit 1
else
    CHANNEL_ID=$1
fi


if  [ ! -n "$2" ] ;then
    echo "you must set PROJECT_PATH"
    exit 1
else
    PROJECT_PATH=$2
fi

export PATH=${PROJECT_PATH}/bin:$PATH
export FABRIC_CFG_PATH=${PROJECT_PATH}/config

export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel fetch config ${CHANNEL_ID}_config_block.pb -o orderer.example.com:7050 -c ${CHANNEL_ID} --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

configtxlator proto_decode --input ${CHANNEL_ID}_config_block.pb --type common.Block --output ${CHANNEL_ID}_config_block.json

jq .data.data[0].payload.data.config ${CHANNEL_ID}_config_block.json > ${CHANNEL_ID}_config.json

cp ${CHANNEL_ID}_config.json ${CHANNEL_ID}_modified_config.json
