
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
 
  it(`(deployment) contract have correct initial isOperational() value`, async function () {

    // Get operating status
    let statusData = await config.flightSuretyData.isOperational.call();
    let statusApp = await config.flightSuretyApp.isOperational.call();
    assert.equal(statusData, true, "Incorrect initial operating status value for Data contract");
    assert.equal(statusApp, true, "Incorrect initial operating status value for App contract");

  });

  it(`(access control) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[9] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(access control) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

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

  it(`(access control) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSuretyApp.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) First airline is registered when contract is deployed', async () => {
    
    let result = await config.flightSuretyApp.isAirlineRegistered(config.firstAirline);
    assert.equal(result, true, "First airline not registered when contract was deployed");

  });

  it('(airline) First airline cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = config.testAddresses[0]; // First airline is not funded in deployment.

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {

    }
    let result = await config.flightSuretyApp.isAirlineRegistered(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });

  it('(airline) First airline can be funded', async () => {
    
    // Funds airline
    //let accountNonce = await web3.eth.getTransactionCount(config.firstAirline)
    await config.flightSuretyApp.fundAirline({from: config.firstAirline, value: web3.utils.toWei('10', 'ether')});
    
    let balanceInContract = await config.flightSuretyApp.getAirlineBalance(config.firstAirline);
    console.log("First Airline Balance in the contract after funding (ether): ", web3.utils.fromWei(balanceInContract, "ether"));//BigNumber(balance).toNumber());
    /* 
    let accountBalance = await web3.eth.getBalance(config.firstAirline);
    console.log("First Airline account balance: ",  web3.utils.fromWei(accountBalance, "ether"));
 */
    let contractBalance = await web3.eth.getBalance(config.flightSuretyData.address);
    console.log("Data Contract balance after funding: ",  web3.utils.fromWei(contractBalance, "ether"));

    let result = await config.flightSuretyApp.isAirlineFunded(config.firstAirline);
    assert.equal(result, true, "First airline couldn´t be funded");

  });
 
  it('(airline) First airline can register testAddresses[0] after being funded', async () => {
    
    //let accountNonce = await web3.eth.getTransactionCount(config.firstAirline);
    await config.flightSuretyApp.registerAirline(config.testAddresses[0], {from: config.firstAirline});

    let result = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[0]);
    assert.equal(result, true, "First airline, once funded couldn´t register a new airline");

  });

  it('(airline) firstAirline could register only first 4 airlines out of 6', async () => {
   
    /* REGISTRATION -------------------------------------------------------------------------------*/
    // At this point firstAirline is registered and funded whereas testAddresses[0] is just registered
    // firstAirline will register 3 more airlines to get a total of 5 registered addresses
   
    await config.flightSuretyApp.registerAirline(config.testAddresses[1], {from: config.firstAirline});
    await config.flightSuretyApp.registerAirline(config.testAddresses[2], {from: config.firstAirline});
    await config.flightSuretyApp.registerAirline(config.testAddresses[3], {from: config.firstAirline}); // 5th airline won´t be registered without consensus
    await config.flightSuretyApp.registerAirline(config.testAddresses[4], {from: config.firstAirline});

    let count = await config.flightSuretyData.countAirlinesRegistered();
    console.log("Airlines registered: ", count);

    let registered = await config.flightSuretyApp.isAirlineRegistered(config.firstAirline);
    let registered0 = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[0]);
    let registered1 = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[1]);
    let registered2 = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[2]);
    let registered3 = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[3]); // 5th airline won´t be registered without consensus
    let registered4 = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[4]);

    
    console.log("Airlines registered firstAirline: ", registered);
    console.log("Airlines registered testAddresses[0]: ", registered0);
    console.log("Airlines registered testAddresses[1]: ", registered1);
    console.log("Airlines registered testAddresses[2]: ", registered2);
    console.log("Airlines registered testAddresses[3]: ", registered3); // 5th airline won´t be registered without consensus
    console.log("Airlines registered testAddresses[4]: ", registered4);

    assert.equal(registered & registered0 & registered1 & registered2, true, "Registration of 5 airlines went wrong");

    /* FUNDING -------------------------------------------------------------------------------*/
    // Fund the 4 new registered airlines
    await config.flightSuretyApp.fundAirline({from: config.testAddresses[0], value: web3.utils.toWei('10', 'ether')});
    await config.flightSuretyApp.fundAirline({from: config.testAddresses[1], value: web3.utils.toWei('10', 'ether')});
    await config.flightSuretyApp.fundAirline({from: config.testAddresses[2], value: web3.utils.toWei('10', 'ether')});


    let funded = await config.flightSuretyApp.isAirlineFunded(config.firstAirline);
    let funded0 = await config.flightSuretyApp.isAirlineFunded(config.testAddresses[0]);
    let funded1 = await config.flightSuretyApp.isAirlineFunded(config.testAddresses[1]);
    let funded2 = await config.flightSuretyApp.isAirlineFunded(config.testAddresses[2]);

    assert.equal(funded & funded0 & funded1 & funded2, true, "Funding of 5 airlines went wrong");

    let accountBalance = await web3.eth.getBalance(config.flightSuretyData.address);
    console.log("Contract balance: ",  web3.utils.fromWei(accountBalance, "ether"));

  });

  it('(consensus) Fifth airline will be registered with consensus - An extra vote', async () => {

    // One vote from the previous test, plus a new vote now:
    await config.flightSuretyApp.registerAirline(config.testAddresses[3], {from: config.testAddresses[2]});

    let registered = await config.flightSuretyApp.isAirlineRegistered(config.testAddresses[3]);
    let votes = await config.flightSuretyApp.getAirlineVotes(config.testAddresses[3])

    assert.equal(registered, true, "Registration of 5th airline went wrong");
    console.log("votes: ", votes);
    assert.equal(votes>=2, true, "Registration of 5th airline went wrong");

  });

});
