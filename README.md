# how to use separate orderers per channel

Every channel will run on a separate instance of the Raft protocol. Put another way: a network that serves N channels, means we have N Raft clusters, each with their own leader. When the clusters are spread across different nodes (as we would like it to be the case eventually), this further decentralizes the service. Even when these clusters are spread across the same nodes however (as we expect the current, default case to be), this gives us the ability to have different leaders per channel.

we can get this information from official documents,but there is no official document telling us how to use separate orderers per channel.

what means "separate orderers per channel",according to official document (reference https://hyperledger-fabric.readthedocs.io/en/release-2.2/orderer/ordering_service.html#raft-concepts)

```
The ordering nodes actively participating in the consensus mechanism for a given channel and receiving replicated logs for the channel. This can be all of the nodes available (either in a single cluster or in multiple clusters contributing to the system channel), or a subset of those nodes.
```

Bluntly, we have R Raft orderer nodes, we can configure channels to use N < R consenters for a specific channel ,for instance,we have 5 raft orderer nodes,and we can configure channels  channel1 to use 4 orderer nodes.

### 1、how to configure to use separate orderers per channel

contains follow steps

- start your network
- ceate and join application channel
- update application channel config

#### 1.1 clone git repository

```bash
$ git clone https://github.com/iamlzw/separate-orderers-per-channel.git
$ cd separate-orderers-per-channel
```

#### 1.2 start fabric network

we create a application called "channel2"

```bash
$ cd separate-orderers-per-channel
### start test netwrok
$ ./raft_start.sh
### echo pwd as parameter ${PROJECT_PATH}
$ pwd
/home/www/go/src/github.com/hyperledger/fabric-samples/separate-orderers-per-channel
#### set CHANNEL_ID
$ CHANNEL_ID=channel2
#### set PROJECT_PATH which is your project path
$ PROJECT_PATH=/home/www/go/src/github.com/hyperledger/fabric-samples/separate-orderers-per-channel
### init test network
$ ./raft_init.sh ${PROJECT_PATH}
```

#### 1.3 update channel config 

The system channel is used by the ordering service as a template to create application channels. The nodes of the ordering service that are defined in the system channel become the default consenter set of new channels, while the administrators of the ordering service become the orderer administrators of the channel. The channel MSPs of channel members are transferred to the new channel from the system channel. After the application channel is created, ordering nodes can be added or removed from the application  channel by updating the channel configuration.  

to use separate orderers for channel2,we will remove an ordering nodes(orderer5.example.com) from our channel2

you can refference official document https://hyperledger-fabric.readthedocs.io/en/release-2.2/config_update.html

1.3.1 Pull and translate the config

```bash
########## export peer0.org1.example.com env
export PATH=${PROJECT_PATH}/bin:$PATH
export FABRIC_CFG_PATH=${PROJECT_PATH}/config/

export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

### fetch config block
peer channel fetch config ${CHANNEL_ID}_config_block.pb -o orderer.example.com:7050 -c ${CHANNEL_ID} --tls --cafile ${PROJECT_NAME}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

### decode config block into json format
configtxlator proto_decode --input ${CHANNEL_ID}_config_block.pb --type common.Block --output ${CHANNEL_ID}_config_block.json

### scope out all of the unnecessary metadata from the config
jq .data.data[0].payload.data.config ${CHANNEL_ID}_config_block.json > ${CHANNEL_ID}_config.json

### make a copy of config.json called modified_config.json. Do not edit config.json directly
cp ${CHANNEL_ID}_config.json ${CHANNEL_ID}_modified_config.json

```

these step almost same as `fetch_config_block.sh`,you can also run `fetch_config_block.sh`

```bash
$ ./fetch_config_block.sh ${CHANNEL_ID} ${PROJECT_PATH}
```

##### 1.3.2 modify the config 

At this point, you have two options of how you want to modify the config.

1. Open `modified_config.json` using the text editor of your choice and make edits. Online tutorials exist that describe how to copy a file from a container that does not have an editor, edit it, and add it back to the container.
2. Use `jq` to apply edits to the config.

we will remove orderer5.example.com tls cert and endpoint,here I use vscode to edit `modified_config.json`

###### a)remove tls

remove orderer5.example.com tls from channel2 config

**before** 

![image.png](http://lifegoeson.cn:8888/images/2021/06/03/image.png)

**after** 

![image51f4588dd86ae78a.png](http://lifegoeson.cn:8888/images/2021/06/03/image51f4588dd86ae78a.png)

###### b)remove endpoint

remove orderer5.example.com endpoint from channel2 config

**before**

![image707990cc59060838.png](http://lifegoeson.cn:8888/images/2021/06/03/image707990cc59060838.png)

**after**

![image3334503423243190.png](http://lifegoeson.cn:8888/images/2021/06/03/image3334503423243190.png)

#### 1.3.3 Re-encode and submit the config

```bash
$ configtxlator proto_encode --input ${CHANNEL_ID}_config.json --type common.Config --output ${CHANNEL_ID}_config.pb

$ configtxlator proto_encode --input ${CHANNEL_ID}_modified_config.json --type common.Config --output ${CHANNEL_ID}_modified_config.pb

$ configtxlator compute_update --channel_id ${CHANNEL_ID} --original ${CHANNEL_ID}_config.pb --updated ${CHANNEL_ID}_modified_config.pb --output ${CHANNEL_ID}_config_update.pb

$ configtxlator proto_decode --input ${CHANNEL_ID}_config_update.pb --type common.ConfigUpdate --output ${CHANNEL_ID}_config_update.json

$ echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_ID}'", "type":2}},"data":{"config_update":'$(cat ${CHANNEL_ID}_config_update.json)'}}}' | jq . > ${CHANNEL_ID}_config_update_in_envelope.json

$ configtxlator proto_encode --input ${CHANNEL_ID}_config_update_in_envelope.json --type common.Envelope --output ${CHANNEL_ID}_config_update_in_envelope.pb

```

these step almost same as `update_config.sh`,you can also run `update_config.sh`

```bash
./update_config.sh ${CHANNEL_ID} ${PROJECT_PATH}
```



#### 1.3.4 sign by organizations admin

once you’ve successfully generated the new configuration protobuf file, it will need to satisfy the relevant policy for whatever it is you’re trying to change, typically (though not always) by requiring signatures from other organizations. 

run these in terminal

```bash

### export peer0.org1.example.com env 
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

#### sign by org1 admin
peer channel signconfigtx -f config_update_in_envelope.pb


### export peer0.org2.example.com env 
export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:9051

#### sign by org2 admin
peer channel signconfigtx -f config_update_in_envelope.pb


### export OrdererMSP env 
export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_CERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp
export CORE_PEER_ADDRESS=peer0.org2.example.com:9051

peer channel update -f config_update_in_envelope.pb -c channel2 -o orderer.example.com:7050 --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

```

### 2、test

```bash
### export peero.org1 env 

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051

```

use orderer5.example.com,will get error 

```bash
peer channel fetch newest -c channel2 -o orderer5.example.com:11050 --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer5.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

![image2a5b9c0a1ba4132e.png](http://lifegoeson.cn:8888/images/2021/06/03/image2a5b9c0a1ba4132e.png)

orderer5.example.com logs

![image23ce83972b5ed306.png](http://lifegoeson.cn:8888/images/2021/06/03/image23ce83972b5ed306.png)

use orderer4.example.com,will success

```bash
peer channel fetch newest -c channel2 -o orderer4.example.com:10050 --tls --cafile ${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer4.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
```

![image28873e776a0b1afa.png](http://lifegoeson.cn:8888/images/2021/06/03/image28873e776a0b1afa.png)

### 3、Q&A

Q: Error: got unexpected status: SERVICE_UNAVAILABLE -- update of more than one consenter at a time is not supported, requested changes: add 0 node(s), remove 2 node(s)

A: this erorr cause by you try to update more than one consenter at a time,you can reference more informations about "membership change in raft"

Q: 0 sub-policies were satisfied, but this policy requires 1 of the 'admins' sub-policies to be satisfied

A:when I try to update channel config with peer admin msp,I meet this error。The solution is use orderer admin msp

uncorrect

```yaml
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_TLS_CERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
```

correct

```yaml
export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_CERT_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.crt
export CORE_PEER_TLS_KEY_FILE=${PROJECT_PATH}/crypto-config/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/server.key
export CORE_PEER_TLS_ROOTCERT_FILE=${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PROJECT_PATH}/crypto-config/ordererOrganizations/example.com/users/Admin@example.com/msp
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
```


