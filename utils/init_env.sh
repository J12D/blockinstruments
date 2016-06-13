#! /bin/bash

# Install solc
yes | sudo add-apt-repository ppa:ethereum/ethereum-qt
yes | sudo add-apt-repository ppa:ethereum/ethereum
# sudo add-apt-repository ppa:ethereum/ethereum-dev
sudo apt-get update
sudo apt-get install cpp-ethereum

# Install latest node.js
#mkdir $HOME/.local
#cd $HOME/.local
#wget https://nodejs.org/dist/v0.12.7/node-v0.12.7-linux-x64.tar.gz
#tar xvzf node-v0.12.7-linux-x64.tar.gz
#cd $OLDPWD

sudo apt-get install git
sudo apt-get install nodejs
sudo apt-get install npm

# Install web3 and truffle
sudo apt-get install git
sudo npm install -g web3
sudo npm install -g truffle

# Install testrpc
sudo apt-get install python-dev
sudo apt-get install python-pip
sudo apt-get install pkg-config
sudo apt-get install libffi-dev
sudo pip install --upgrade setuptools
sudo pip install pysha3
sudo pip install repoze.lru
sudo apt-get install libssl-dev
sudo pip install scrypt
sudo pip install pycrypto
sudo pip install pbkdf2
sudo pip install rlp
sudo pip install bitcoin
sudo pip install pyethash
sudo npm install -g ethereumjs-testrpc
#sudo pip install eth-testrpc
