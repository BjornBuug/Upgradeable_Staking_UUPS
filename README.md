# Staking Smart Contract

This repository contains a UUPS (Universal Upgradeable Proxy Standard) compliant smart contract that enables users to stake, unstake, and claim tokens. It's written in Solidity and includes features for pausability and upgradability.


Overview

<a href="https://ibb.co/0rc1Cw0"><img src="https://i.ibb.co/Wf67kTr/Propertytitle.png" alt="Propertytitle" border="0"></a>


### Contract Functions:

### Modifiers
- `onlyManager()`
- `onlyOwner()`

### Contract Initialization
- `constructor()`

### Property Functions
- `createProperty(string memory tokenURI, uint256 instrumentNum)`
- `setTokenURI(uint256 tokenId, string memory _tokenURI)`
- `recordProperty(uint256 tokenId, uint256 instrumentNum)`

### Data Retrieval Functions
- `fetchAllPropertiesByManagers()`
- `fetchAllProperties()`
- `fetchPropertiesByNum(uint256 _instrumentNum)`
- `fetchUserProperty()`

### Manager Functions
- `addManager(address _newManager)`
- `approvedPropertyStatus(uint256 tokenId)`

### Contract Address

[View Property Title Recorder Smart Contract on Sepolia Testnet](https://sepolia.etherscan.io/address/0xc495512d4dfeb2ad5ad180af4613b9411eafa467)


## Foundry Test
Follow the [instructions](https://book.getfoundry.sh/getting-started/installation.html) to install [Foundry](https://github.com/foundry-rs/foundry).

Clone and install dependencies: git submodule update --init --recursive  
Test Contract: ```forge test --contracts ./src/test/PropertyRecorder.t.sol -vvvv```

