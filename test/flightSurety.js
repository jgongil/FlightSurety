
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    config = await Test.Config(accounts);

    // Grant access to app contract to call data contract
    console.log('\nData Contract used for testing', config.flightSuretyData.address);
    console.log('App Contract used for testing', config.flightSuretyApp.address);
    await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address);


    // register first airline (owner)
    console.log('owner - accounts[0]:', await config.owner); 
    console.log('firstAirline - accounts[2]:', await config.firstAirline);    

  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/
 
  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) first airline is registered when contract is deployed', async () => {
    
    let result = await config.flightSuretyApp.isAirlineRegistered.call(config.firstAirline);
    assert.equal(result, true, "First airline not registered when contract was deployed");

  });

  it('(airline) first airline is funded', async () => {
    
    await config.flightSuretyApp.fundAirline({from: config.firstAirline, value: web3.utils.toWei('10', 'ether')});
    
    let balanceInContract = await config.flightSuretyApp.getAirlineBalance.call(config.firstAirline);
    console.log("First Airline Balance in the contract after funding (ether): ", web3.utils.fromWei(balanceInContract, "ether"));//BigNumber(balance).toNumber());
    /* 
    let accountBalance = await web3.eth.getBalance(config.firstAirline);
    console.log("First Airline account balance: ",  web3.utils.fromWei(accountBalance, "ether"));
 */
    let contractBalance = await web3.eth.getBalance(config.flightSuretyData.address);
    console.log("Data Contract balance after funding: ",  web3.utils.fromWei(contractBalance, "ether"));

    let result = await config.flightSuretyApp.isAirlineFunded.call(config.firstAirline);
    assert.equal(result, true, "First airline not funded when contract was deployed");

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[3];

    // ACT
    try {
        await config.flightSuretyApp.isAirlineRegistered(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
 

});
