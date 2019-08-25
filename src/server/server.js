import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

// Oracle status codes
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;

// ORACLE REGISTRATION starts

const TEST_ORACLES_COUNT = 5;


flightSuretyApp.events.OracleRequest({
    fromBlock: 'latest'
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event) // submitOracleResponse comes here
});

flightSuretyApp.events.OracleReport({
  fromBlock: 0
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
});

flightSuretyApp.events.FlightStatusInfo({
  fromBlock: 0
}, function (error, event) {
  if (error) console.log(error)
  console.log(event)
});


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


