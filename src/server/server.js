import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
import 'babel-polyfill';

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let accounts;
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

// Oracle status codes
const STATUS_CODE_UNKNOWN = 0;
const STATUS_CODE_ON_TIME = 10;
const STATUS_CODE_LATE_AIRLINE = 20;
const STATUS_CODE_LATE_WEATHER = 30;
const STATUS_CODE_LATE_TECHNICAL = 40;
const STATUS_CODE_LATE_OTHER = 50;
const ORACLES_COUNT = 5;


web3.eth.getAccounts(async (error, acc) => {
  accounts = acc;
  // Register oracles at server startup
  await initOracleRegistration();

  // Listening to events
/*   flightSuretyApp.events.OracleRequest({
    fromBlock: 'latest'
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event) // submitOracleResponse comes here
  }); */
  
  //Listening to Oracle Requests
  await flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, oracleRequestHandler);

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


});


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

async function initOracleRegistration() {

  // Based on Oracle test cases
  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  for(let a=1; a<ORACLES_COUNT; a++) {      
    await flightSuretyApp.methods.registerOracle().send({ from: accounts[a], value: fee, gas: 3000000 });
    let result = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[a]});
    console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
  } 

}

async function oracleRequestHandler(error, event) {
  if (error) console.log(error)
  console.log("Oracle request handler working");
  console.log(event);

  try {
    for (let i = 1; i < ORACLES_COUNT; i++) {
        let indexes = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]});
        if (indexes.indexOf(event.returnValues.index) >= 0) {
            console.log("Oracle %d, address %s, indexes %d %d %d, select: %s", i, accounts[i], indexes[0], indexes[1], indexes[2], event.returnValues.index);
            const pos = 2;

            await flightSuretyApp.methods
                .submitOracleResponse(
                    event.returnValues.index,
                    event.returnValues.airline,
                    event.returnValues.flight,
                    event.returnValues.timestamp,
                    STATUS_CODE_LATE_AIRLINE
                )
                .send({from: accounts[i], gas: 5000000});
        }
      }
  } catch (e) {
      console.log(e);
  }

}
export default app;


