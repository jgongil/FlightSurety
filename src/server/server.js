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
/* STATUS_CODE_UNKNOWN = 0;
STATUS_CODE_ON_TIME = 10;
STATUS_CODE_LATE_AIRLINE = 20;
STATUS_CODE_LATE_WEATHER = 30;
STATUS_CODE_LATE_TECHNICAL = 40;
STATUS_CODE_LATE_OTHER = 50; */

const ORACLES_COUNT = 20;
const STATUS_CODES = [0, 10, 20, 30, 40, 50];
let nresp = 0; // number of successful responses

web3.eth.getAccounts(async (error, acc) => {
  accounts = acc;
  // Register oracles at server startup
  await initOracleRegistration();
  
  /* Listening to EVENTS */

  // Listening to Oracle Requests
  await flightSuretyApp.events.OracleRequest({
    fromBlock: 'latest'
  }, oracleRequestHandler); // -> OracleRequestHandler is triggered

  // Listening to Oracle Reports
  await flightSuretyApp.events.OracleReport({
    fromBlock: 'latest'
  }, function (error, event) {
    if (error) console.log(error)
    console.log("Oracle report event received: ", event)
  });

  // Listening to FlightStatusInfo
  await flightSuretyApp.events.FlightStatusInfo({
    fromBlock: 'latest'
  }, function (error, event) {
    if (error) console.log(error)
    console.log("Flight Status Info event received: ", event)
  });

});


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})


async function initOracleRegistration() {

  // Based on Oracle test cases, starting with the registration of ORACLES_COUNT oracles
  let fee = await flightSuretyApp.methods.REGISTRATION_FEE().call();
  for(let a=1; a<ORACLES_COUNT; a++) {      
    await flightSuretyApp.methods.registerOracle().send({ from: accounts[a], value: fee, gas: 3000000 });
    let result = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[a]});
    console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
  } 

}

// OracleRequest event is handled
async function oracleRequestHandler(error, event) {
  if (error) console.log(error)
  console.log("Oracle request handler working");
  console.log("Oracle request Event Received: ", event);

  try {

    for (let i = 1; i < ORACLES_COUNT; i++) { // Iterate every oracle registered previously

        let indexes = await flightSuretyApp.methods.getMyIndexes().call({from: accounts[i]}); // Retrives indexes assigned to the Oracle during registration

        if (indexes.indexOf(event.returnValues.index) >= 0) { // when the index received in OracleRequest one of the oracle´s indexes
            console.log("Oracle %d, address %s, indexes %d %d %d, select: %s", i, accounts[i], indexes[0], indexes[1], indexes[2], event.returnValues.index);
            ++nresp;
            let codeIndex = getRandomStatus(STATUS_CODES.length - 1);
            let code = STATUS_CODES[codeIndex];

            await flightSuretyApp.methods
                .submitOracleResponse(
                    event.returnValues.index,
                    event.returnValues.airline,
                    event.returnValues.flight,
                    event.returnValues.timestamp,
                    code
                )
                .send({from: accounts[i], gas: 5000000});

/*                 uint8 index,
                address airline,
                string flight,
                uint256 timestamp,
                uint8 statusCode */
        }
      }
      console.log("Number of successful responses: ",nresp);
  } catch (e) {
      console.log(e);
  }

}

function getRandomStatus(maxVal){
  return  Math.round(Math.random() * maxVal);
}

export default app;


