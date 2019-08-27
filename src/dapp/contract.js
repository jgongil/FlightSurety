import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
        this.config = config;
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            // Authorizes app contract to operate on data contract
            this.authorizeContract(this.config, (error, result) => {
                console.log(error,"Result of Authorization: " + result);
            });

            // Flight Registration is harcoded when client starts
            let flights = ['MAD-0184','LON-0007'];
            flights.forEach( async (flight, key) => {
                await this.registerFlight(flight, (error, result) => {
                    if (error) console.log("Flight Regisration error: ",error);
                    console.log("Flight Registered: ", result);
                });
            });


            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    async authorizeContract(config,callback) {
        let self = this;
        let payload = {
            address: config.appAddress//"0xA4392264a2d8c998901D10C154C91725b1BF0158"
        };
        console.log("Authorizing App Contract: ",payload.address);
        console.log("Owner Authorizing: ",self.owner);
        await self.flightSuretyData.methods
            .authorizeContract(payload.address)
            .send({from: self.owner},(error, result) => {
                callback(error,result);
            });
    }

    async registerFlight(flightName, callback){
        let self = this;
        let payload = {
            name:flightName,
            statusCode: 0,
            updatedTimestamp: Math.floor(Date.now() / 1000),
            airline: self.airlines[3]
        }
        
        await self.flightSuretyApp.methods
            .registerFlight(payload.name,payload.statusCode,payload.updatedTimestamp,payload.airline)
            .send({from: self.owner,gas: 4712388, gasPrice: 100000000000}, (error, result) => {
                callback(error,payload);
            });
    }

    async getRegisteredFlights(callback) {
        let self = this;
        await self.flightSuretyApp.methods
             .getRegisteredFlights()
             .call({ from: self.owner},callback);
    }

    async buy(flightName, timestamp, amount, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[3],
            flight: flightName,
            timestamp: timestamp,
            amount: amount
            }
        await self.flightSuretyApp.methods
             .buy(payload.airline,payload.flight,payload.timestamp)
             .send({from: self.owner,value: payload.amount, gas: 4712388, gasPrice: 100000000000}, (error, result) => {
                callback(error,payload);
            });
    }

}