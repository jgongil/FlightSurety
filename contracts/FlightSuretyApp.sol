pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    //Control flag to pause contract from running state changing operations
    bool private operational = true;

    address private contractOwner;          // Account used to deploy contract
       
    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Maximum payable price for an insurance
    uint256 private constant MAX_INSURANCE_PRICE = 1 ether;

    // Data Contract
    FlightSuretyData flightSuretyData; //State variable referencing the data contract deployed. It´s initiated in the constructor

    // Consensus data
    mapping(address => address[]) private airlineVotes;
    address[] airlineProRegister = new address[](0);

    // Fees for airlines to join
    uint256 public constant JOIN_FEE = 10 ether; 

    // EVENTS
    event flightStatusProcessed(address airline, string flight, uint256 timestamp, uint8 statusCode);
    event soldInsurance(address airline,string flightName,uint256 timestamp);
    event lateArrival(address airline,string flightName,uint256 timestamp);
    
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(operational, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/


    /**
    * @dev Contract constructor
    *
    */
    constructor
                (
                    address dataContract //Address of data contract
                ) 
                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract); //Reference to data contract
        
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/
// UTILITIES start ------

    function isOperational() 
                            public
                            pure
                            returns(bool)
    {
        return true;  // Modify to call data contract's status
    }

    function isAirlineRegistered(
                        address airline
                        )
                        external
                        view
                        //requireContractOwner
                        returns(bool)
    {
        return flightSuretyData.isAirlineRegistered(airline);
    }

    function isAirlineFunded(
                            address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return flightSuretyData.isAirlineFunded(airline);
    }

    function getAirlineBalance  (
                                address airline
                                )
                                external
                                view
                                returns(uint256)
    {
        return flightSuretyData.getAirlineBalance(airline);
    }

    function getAirlineVotes  (
                                address airline
                                )
                                external
                                view
                                returns(uint256)
    {
        return airlineVotes[airline].length;
    }

    function isFlightRegistered(
                            address airline,
                            string flightName,
                            uint256 timestamp
                            )
                            external
                            view
                            returns(bool)
    {
        return flightSuretyData.isFlightRegistered(airline, flightName, timestamp);
    }

    function getRegisteredFlights()
                                    external
                                    view
                                    returns(string[] memory,uint256[] memory,address[] memory)
    {
        return flightSuretyData.getRegisteredFlights();
    }
    function getInsuredFlights(
                                address insureeAddress
                                )
                        external
                        view
                        returns(string[] memory,uint256[] memory,address[] memory)
    {
        return flightSuretyData.getInsuredFlights(insureeAddress);
    }

    function isInsured    (
                    address insuree,
                    address airline,
                    string flightName,
                    uint256 timestamp
                    )
                    external
                    view
                    returns(bool)
    {
        return flightSuretyData.isInsured(insuree,airline,flightName,timestamp);
    }

// UTILITIES end ------

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

// AIRLINE HANDLING starts ------

   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                            (
                                address airlineToRegister
                            )
                            external
                            returns(bool success, uint256 votes)
    {
        require(this.isAirlineFunded(msg.sender), "A non-funded airline cannot register");
        require(!this.isAirlineRegistered(airlineToRegister), "The airline is already registered");

        // Registered airlines counts
        uint256 airlinesCount = flightSuretyData.countAirlinesRegistered(); // Numer of registered airlines
        uint256 airlineMajority = airlinesCount.div(2); // Number of airlines which conform the majority

        // 1) When less than 5 airlines are registered, any registered airline can perform registration
        if (airlinesCount < 4){
                    flightSuretyData.registerAirline(airlineToRegister);
        }
        // 2) Multi party consensus handling - 50% of the reg airlines must have voted for airlineToRegiter
        else {

            bool isDuplicate = false;
            for (uint c=0; c < airlineVotes[airlineToRegister].length; c++) {

                if (airlineVotes[airlineToRegister][c] == msg.sender) {
                    isDuplicate = true;
                    break;
                }
            }

            require(!isDuplicate, "Caller has already called this function. (Cannot vote twice)");

            airlineVotes[airlineToRegister].push(msg.sender); // VOTE: New airline pro registering airlineToRegister

            // If > 50% airlines voted for airlineToRegister, the regitration will succeed.
            if (airlineVotes[airlineToRegister].length >= airlineMajority) {
                flightSuretyData.registerAirline(airlineToRegister);
                //airlineVotes[airlineToRegister] = new address[](0);
            }

        }
        return (success, 0);
    }

    function fundAirline
                            (
                            )
                            external
                            payable
    {
    /*         uint256 amountToReturn = msg.value - JOIN_FEE;
        address(dataContractAddress).transfer(JOIN_FEE);
        msg.sender.transfer(amountToReturn); */

        // The airline must be registered already as first step
        require(this.isAirlineRegistered(msg.sender), "Airline is not registered so cannot be funded");
        // Check if it´s already funded
        require(!this.isAirlineFunded(msg.sender), "Airline is already funded");
        // Transaction has the minimun joining fee
        require(msg.value >= JOIN_FEE,"The transaction value doesn´t meet the joining fee");
        flightSuretyData.fundAirline.value(msg.value)(msg.sender);
    }

// AIRLINE HANDLING ends ------

// FLIGHT HANDLING starts ------
   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight
                                (
                                    string flightName,
                                    uint8 statusCode,
                                    uint256 updatedTimestamp,
                                    address airline
                                )
                                external
                                requireIsOperational
    {
        require(!this.isFlightRegistered(airline,flightName,updatedTimestamp), "The flight is already registered");
        flightSuretyData.registerFlight(flightName,statusCode,updatedTimestamp,airline);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                requireIsOperational
    {
        require(this.isFlightRegistered(airline,flight,timestamp), "The flightCode provided is not registered");

        if (statusCode==STATUS_CODE_LATE_AIRLINE){ // With late arrival we can automatically credit the passengers

            emit lateArrival(airline, flight, timestamp);
            address[] memory listToCredit = this.getInsurees(airline,flight,timestamp);
            for (uint i = 0; i < listToCredit.length; ++i) {
                this.creditInsurees(listToCredit[i], airline,flight,timestamp);
            }
        }
        emit flightStatusProcessed(airline, flight, timestamp, statusCode);
    }


    // Generate a request for oracles to fetch flight information - triggered from the UI
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp                            
                        )
                        external
                        requireIsOperational
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }

// FLIGHT HANDLING ends ------

// PASSENGER HANDLING starts ------

    function buy
                            (
                                address airline,
                                string flightName,
                                uint256 timestamp
                            )
                            external
                            payable
                            requireIsOperational
    {
        require(this.isFlightRegistered(airline,flightName,timestamp), "The flightCode provided is not registered");
        require(msg.value <= MAX_INSURANCE_PRICE, "Max payable amount is 1 ether");
        require(msg.value > 0, "No ether sent");
        require(!this.isInsured(msg.sender,airline,flightName,timestamp),"The passenger already bought and insurance for this flight");
        flightSuretyData.buy.value(msg.value)(msg.sender,airline,flightName,timestamp);

        emit soldInsurance(airline,flightName,timestamp);
    }

    function creditInsurees
                                (
                                    address insuree,
                                    address airline,
                                    string flightName,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
                                
    {
        require(this.isFlightRegistered(airline,flightName,timestamp), "The flightCode provided is not registered");
        require(this.isInsured(insuree,airline,flightName,timestamp),"The passenger is not insured for this flight");
        flightSuretyData.creditInsurees(insuree,airline,flightName,timestamp);
    }

    function pay
                            (
                            )
                            external
                            requireIsOperational
    {
        require(flightSuretyData.getInsureeCredit(msg.sender) > 0, "Passenger doesn´t have any payout credit");
        flightSuretyData.pay(msg.sender);
    }

    function getInsurees    (
                                address airline,
                                string flightName,
                                uint256 timestamp
                            )
                            external
                            view
                            returns(address[] memory)
    {
        require(this.isFlightRegistered(airline,flightName,timestamp), "The flightCode provided is not registered");
        return flightSuretyData.getInsurees(airline,flightName,timestamp);
    }
// PASSENGER HANDLING ends ------

// ORACLE MANAGEMENT starts ------

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// ORACLE MANAGEMENT ends ------
}

// FlightSuretyData INTERFACE starts ------
contract FlightSuretyData { // modifiers are implemented in the data contract
    function registerAirline
                            (
                                address wallet
                            )
                            external;
    function countAirlinesRegistered(
                                    )
                                    external
                                    view
                                    returns(uint256);
    function fundAirline
                            (   
                                address airline
                            )
                            public
                            payable;

    function isAirlineRegistered(
                                    address airline
                                )
                                external
                                view
                                returns(bool);
    function isAirlineFunded(
                                address airline
                            )
                            external
                            view
                            returns(bool);
    function getAirlineBalance  (
                            address airline
                            )
                            external
                            view
                            returns(uint256);
    function registerFlight  (
                                string flightName,
                                uint8 statusCode,
                                uint256 updatedTimestamp,
                                address airline
                            )
                            external;
    function isFlightRegistered(
                            address airline,
                            string flightName,
                            uint256 timestamp
                            )
                            external
                            view
                            returns(bool);
    function buy
                            (
                                address buyer,
                                address airline,
                                string flightName,
                                uint256 timestamp
                            )
                            external
                            payable;
    function creditInsurees
                            (
                                    address insuree,
                                    address airline,
                                    string flightName,
                                    uint256 timestamp
                            )
                            external;
    function pay
                            (
                                address insuree
                            )
                            external;

    function getRegisteredFlights()
                                    external
                                    view
                                    returns(string[] memory,uint256[] memory,address[] memory);
    function getInsuredFlights(
                            address insureeAddress
                            )
                            external
                            view
                            returns(string[] memory,uint256[] memory,address[] memory);
    function isInsured    (
                        address insuree,
                        address airline,
                        string flightName,
                        uint256 timestamp
                        )
                        external
                        view
                        returns(bool);
    function getInsureeCredit(
                            address insuree
                            )
                            external
                            view
                            returns(uint256);
    function getInsurees    (
                                address airline,
                                string flightName,
                                uint256 timestamp
                            )
                            external
                            view
                            returns(address[] memory);

}

// FlightSuretyData INTERFACE ends ------