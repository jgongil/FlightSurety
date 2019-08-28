# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.

## Install

This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

`npm install`
`truffle compile`

Please note the tests were run using `Ganache CLI v6.5.0 (ganache-core: 2.6.0)`

## Develop Client

To run ganache-cli:

`ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" -l 9999999 -e 500`

To run truffle tests:

`truffle test ./test/flightSurety.js`
`truffle test ./test/oracles.js`

Please notice scripts in package.json were updated to avoid conflicts in Windows between truffle.js and truffle.cmd.

``` 
"scripts": {
    "truf": "truffle.cmd",
    "test": "truffle.cmd test ./test/flightSurety.js"
```
To run the tests you might use:  `npm run truf test`

Result of tests can be found [here](./docs/truffle-tests.outcome.md)

To use the dapp:

`truffle migrate`
`npm run dapp`

To view dapp:

`http://localhost:8000`

## Develop Server

`npm run server`
`truffle test ./test/oracles.js`

## Deploy

To build dapp for prod:
`npm run dapp:prod`

Deploy the contents of the ./dapp folder


## Resources

* [How does Ethereum work anyway?](https://medium.com/@preethikasireddy/how-does-ethereum-work-anyway-22d1df506369)
* [BIP39 Mnemonic Generator](https://iancoleman.io/bip39/)
* [Truffle Framework](http://truffleframework.com/)
* [Ganache Local Blockchain](http://truffleframework.com/ganache/)
* [Remix Solidity IDE](https://remix.ethereum.org/)
* [Solidity Language Reference](http://solidity.readthedocs.io/en/v0.4.24/)
* [Ethereum Blockchain Explorer](https://etherscan.io/)
* [Web3Js Reference](https://github.com/ethereum/wiki/wiki/JavaScript-API)