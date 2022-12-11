#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/common.sh)

printLogo

read -p "Enter node moniker: " NOIS_MONIKER

CHAIN_ID="nois-testnet-003"
CHAIN_DENOM="unois"
BINARY="noisd"
CHEAT_SHEET="https://nodejumper.io/nois-testnet/cheat-sheet"

printLine
echo -e "Node moniker: ${CYAN}$NOIS_MONIKER${NC}"
echo -e "Chain id:     ${CYAN}$CHAIN_ID${NC}"
echo -e "Chain demon:  ${CYAN}$CHAIN_DENOM${NC}"
printLine
sleep 1

source <(curl -s https://raw.githubusercontent.com/nodejumper-org/cosmos-scripts/master/utils/dependencies_install.sh)

printCyan "4. Building binaries..." && sleep 1

cd || return
rm -rf full-node
git clone https://github.com/noislabs/full-node.git
cd full-node/full-node/ || return
git checkout nois-testnet-003
./build.sh
mkdir -p $HOME/go/bin
sudo mv out/noisd $HOME/go/bin/noisd
noisd version # 0.29.0-rc2

noisd config keyring-backend test
noisd config chain-id $CHAIN_ID
noisd init $NOIS_MONIKER --chain-id $CHAIN_ID

curl -# https://raw.githubusercontent.com/noislabs/testnets/main/nois-testnet-003/genesis.json > $HOME/.noisd/config/genesis.json
sha256sum $HOME/.noisd/config/genesis.json # 9153084f305111e72fed86f44f6a11711c421532722200c870170d98223233ba

curl -s https://snapshots3-testnet.nodejumper.io/nois-testnet/addrbook.json > $HOME/.noisd/config/addrbook.json

sed -i 's|^minimum-gas-prices *=.*|minimum-gas-prices = "0.005unois"|g' $HOME/.noisd/config/app.toml
seeds=""
peers="ac9122b2c10577bfd52aa248c6344370aff164aa@nois-testnet.nodejumper.io:29656,2bf8002d0f65c3d86fca31ea0f043d912682c3e0@65.109.70.23:17356,2dc7ab934dfec910fac3083fd74e3451e1d3e670@135.181.5.47:21036,d6f3f15d177f2e522f7e488bc3f66b659cc5f681@138.201.141.76:3656"
sed -i -e 's|^seeds *=.*|seeds = "'$seeds'"|; s|^persistent_peers *=.*|persistent_peers = "'$peers'"|' $HOME/.noisd/config/config.toml

# set custom timeouts
sed -i 's|^timeout_propose =.*$|timeout_propose = "2000ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_propose_delta =.*$|timeout_propose_delta = "500ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_prevote =.*$|timeout_prevote = "1s"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_prevote_delta =.*$|timeout_prevote_delta = "500ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_precommit =.*$|timeout_precommit = "1s"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_precommit_delta =.*$|timeout_precommit_delta = "500ms"|' $HOME/.noisd/config/config.toml
sed -i 's|^timeout_commit =.*$|timeout_commit = "1800ms"|' $HOME/.noisd/config/config.toml

# in case of pruning
sed -i 's|pruning = "default"|pruning = "custom"|g' $HOME/.noisd/config/app.toml
sed -i 's|pruning-keep-recent = "0"|pruning-keep-recent = "100"|g' $HOME/.noisd/config/app.toml
sed -i 's|pruning-interval = "0"|pruning-interval = "17"|g' $HOME/.noisd/config/app.toml

printCyan "5. Starting service and synchronization..." && sleep 1

sudo tee /etc/systemd/system/noisd.service > /dev/null << EOF
[Unit]
Description=Noisd Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which noisd) start
Restart=on-failure
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable noisd
sudo systemctl restart noisd

printLine
echo -e "Check logs:            ${CYAN}sudo journalctl -u $BINARY -f --no-hostname -o cat ${NC}"
echo -e "Check synchronization: ${CYAN}$BINARY status 2>&1 | jq .SyncInfo.catching_up${NC}"
echo -e "More commands:         ${CYAN}$CHEAT_SHEET${NC}"
