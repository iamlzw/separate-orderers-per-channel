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


configtxlator proto_encode --input ${CHANNEL_ID}_config.json --type common.Config --output ${CHANNEL_ID}_config.pb

configtxlator proto_encode --input ${CHANNEL_ID}_modified_config.json --type common.Config --output ${CHANNEL_ID}_modified_config.pb

configtxlator compute_update --channel_id ${CHANNEL_ID} --original ${CHANNEL_ID}_config.pb --updated ${CHANNEL_ID}_modified_config.pb --output ${CHANNEL_ID}_config_update.pb

configtxlator proto_decode --input ${CHANNEL_ID}_config_update.pb --type common.ConfigUpdate --output ${CHANNEL_ID}_config_update.json

echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_ID}'", "type":2}},"data":{"config_update":'$(cat ${CHANNEL_ID}_config_update.json)'}}}' | jq . > ${CHANNEL_ID}_config_update_in_envelope.json

configtxlator proto_encode --input ${CHANNEL_ID}_config_update_in_envelope.json --type common.Envelope --output ${CHANNEL_ID}_config_update_in_envelope.pb

peer channel signconfigtx -f ${CHANNEL_ID}_config_update_in_envelope.pb


export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:9051

peer channel signconfigtx -f ${CHANNEL_ID}_config_update_in_envelope.pb

export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_CERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

peer channel update -f ${CHANNEL_ID}_config_update_in_envelope.pb -c ${CHANNEL_ID} -o orderer.example.com:7050 --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

sleep 10s

peer channel fetch newest -o orderer5.example.com:11050 -c ${CHANNEL_ID} --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/msp/tlscacerts/tlsca.example.com-cert.pem


peer channel fetch newest -o orderer4.example.com:10050 -c ${CHANNEL_ID} --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

