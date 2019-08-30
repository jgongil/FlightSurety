pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    address private firstAirline;                                       // First airline is registered when contract is deployed
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    // Airline roles - admin yes/no
    struct AirlineProfile {
        bool isRegistered;
        bool isFunded;
    }
    mapping(address => AirlineProfile) airlineProfiles;  // Mapping for storing user profiles
    address[] registeredAirlines = new address[](0);

    //Restrict Data Contract Callers
     mapping(address => uint256) private authorizedContracts;

    //Airline funded balance
    mapping(address => uint256) internal airlineFunds;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string flightName;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] private flightCodes = new bytes32[](0); // Will store flight codes to enable iteration over flights

    // Flight insurance assets wallet: (Flight+Passenger) -> assetId -> balance
    mapping(bytes32 => uint256) insuranceAssetWallet;

    struct Insurance {
        bytes32 flightCode;
        uint256 value;
    }
    mapping(address => Insurance[]) private passengerInsurances; // Passenger -> Insurances
    mapping(address => uint256) private payouts;
    mapping(bytes32 => address[]) private flightInsurees; // Flight -> Passengers who bought insurance

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event debug(uint i);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address newFirstAirline
                                )
                                public
    {
        contractOwner = msg.sender;
        firstAirline = newFirstAirline;
        // adds airline address to the list of addresses
        registeredAirlines.push(firstAirline);
        // First airline gets registered as admin
        airlineProfiles[firstAirline] = AirlineProfile({
                                                    isRegistered: true,
                                                    isFunded: false
                                                     });
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/
// MODIFIERS start ------

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
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

    modifier requireIsCallerAuthorized()
    {
        require(authorizedContracts[msg.sender] == 1, "Caller is not authorized");
        _;
    }

// MODIFIERS end ------

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

// UTILITIES start ------

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    function authorizeContract
                            (
                                address contractAddress
                            )
                            external
                            //requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeContract
                            (
                                address contractAddress
                            )
                            external
                            requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    function isAirlineRegistered(
                                address airline
                                )
                                external
                                view
                                returns(bool)
    {
        return airlineProfiles[airline].isRegistered;
    }

    function countAirlinesRegistered(
                                    )
                                    external
                                    view
                                    returns(uint256)
    {
        return registeredAirlines.length;
    }

    function isAirlineFunded(
                            address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return airlineProfiles[airline].isFunded;
    }

    function getAirlineBalance  (
                                address airline
                                )
                                external
                                view
                                requireIsCallerAuthorized
                                returns(uint256)
    {
        return airlineFunds[airline];
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
        bytes32 flightCode = getFlightKey(airline, flightName, timestamp);
        return flights[flightCode].isRegistered;
    }

    function getInsureeCredit(
                            address insuree
                            )
                            external
                            view
                            returns(uint256)
    {
        return payouts[insuree];
    }

    // Returns insured flights for a passenger or insuree
    function getInsuredFlights(
                            address insureeAddress
                            )
                            external
                            view
                            returns(string[] memory,uint256[] memory,address[] memory)
    {
        uint256 ninsurances = passengerInsurances[insureeAddress].length;
        string[] memory flightNames = new string[](ninsurances);
        uint256[] memory timestamps = new uint256[](ninsurances);
        address[] memory airlines = new address[](ninsurances);

            for (uint i = 0; i < ninsurances; ++i) {
                bytes32 flightCode = passengerInsurances[insureeAddress][i].flightCode;
                flightNames[i] = flights[flightCode].flightName;
                timestamps[i] = flights[flightCode].updatedTimestamp;
                airlines[i] = flights[flightCode].airline;
            }

        return (flightNames,timestamps,airlines);
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
        bytes32 flightCode = getFlightKey(airline, flightName, timestamp);
        address[] memory listOfInsurees = flightInsurees[flightCode];// Retrieves insurees of a flight
        uint ninsurees = listOfInsurees.length;
        bool insured = false;

        for (uint i = 0; i < ninsurees; ++i) { // Does any of the insurees matches?
            if (insuree == listOfInsurees[i]){
                insured = true;
            }
        }

        return insured;
    }

    function getRegisteredFlights()
                                    external
                                    view
                                    returns(string[] memory,uint256[] memory,address[] memory)
    {

        uint256 ncodes = flightCodes.length;
        string[] memory flightNames = new string[](ncodes);
        uint256[] memory timestamps = new uint256[](ncodes);
        address[] memory airlines = new address[](ncodes);

            for (uint i = 0; i < ncodes; ++i) {
                bytes32 flightCode = flightCodes[i];
                flightNames[i] = flights[flightCode].flightName;
                timestamps[i] = flights[flightCode].updatedTimestamp;
                airlines[i] = flights[flightCode].airline;
            }

        return (flightNames,timestamps,airlines);
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
        bytes32 flightCode = getFlightKey(airline, flightName, timestamp);
        address[] memory listOfInsurees = flightInsurees[flightCode];// Retrieves insurees of a flight
        return listOfInsurees;
    }

// UTILITIES end ------

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
// AIRLINE HANDLING starts ------

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
                            (
                                address wallet
                            )
                            external
                            requireIsOperational
                            requireIsCallerAuthorized
    {

        // adds airline address to the list of registered airline addresses
        registeredAirlines.push(wallet);
        // populates the relevant profile
        airlineProfiles[wallet] = AirlineProfile({
                                                    isRegistered: true,
                                                    isFunded: false
                                                });
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fundAirline
                            (   
                                address airline
                            )
                            public
                            payable
                            requireIsOperational
                            requireIsCallerAuthorized
    {

        airlineFunds[airline] = airlineFunds[airline].add(msg.value); // Keep record of contributions of every company
        airlineProfiles[airline].isFunded = true;

    }
// AIRLINE HANDLING ends ------

// FLIGHTS HANDLING starts ------
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
                                //requireIsCallerAuthorized
    {

        bytes32 flightCode = getFlightKey(airline, flightName, updatedTimestamp);
        // require(!flights[flightCode].isRegistered, "Flight already registered"); -> checked in app contract
        flights[flightCode] = Flight({
                                        isRegistered: true,
                                        statusCode:statusCode,
                                        updatedTimestamp:updatedTimestamp,
                                        airline: airline,
                                        flightName: flightName

                                    });
        flightCodes.push(flightCode); // adding the new code to a list for further iteration over all flights
    }


    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
// FLIGHTS HANDLING ends ------

// PASSENGER HANDLING starts ------
   /**
    * @dev Buy insurance for a flight: Passenger buys insurance based on flight name and timestamp.
    *
    */
    function buy
                            (
                                address buyer,
                                address airline,
                                string flightName,
                                uint256 timestamp
                            )
                            external
                            payable
                            requireIsOperational
                            requireIsCallerAuthorized
    {
        bytes32 flightCode = getFlightKey(airline, flightName, timestamp);

        //  mapping(address => Insurance[]) private insurances;
        // Insurance policy definition
        Insurance memory newInsurance = Insurance({
                                        flightCode:flightCode,
                                        value: msg.value
                                    });
        Insurance[] storage currentInsurances = passengerInsurances[buyer];
        currentInsurances.push(newInsurance); // We add the new insurance to the list of insurances of the user
        passengerInsurances[buyer] = currentInsurances;

        address[] storage listOfInsurees = flightInsurees[flightCode];
        listOfInsurees.push(buyer); // We add the insuree to the list of passengers insured by flightCode
        flightInsurees[flightCode] = listOfInsurees;

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address insuree,
                                    address airline,
                                    string flightName,
                                    uint256 timestamp
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    
    {
        bytes32 flightCode = getFlightKey(airline, flightName, timestamp);
        // address[] memory insureesToCredit = flightInsurees(flightCode); // If I´d like to credit all insurees affected by a flight

        // Retrieves insuree insurances
        Insurance[] memory currentInsurances = passengerInsurances[insuree];
        uint256 creditedAmount = 0;

        for (uint i = 0; i < currentInsurances.length; ++i) { // Checks every insurance
            if (currentInsurances[i].flightCode == flightCode){
                creditedAmount = creditedAmount.add(currentInsurances[i].value.mul(15).div(10)); // For the insurance of the relevant flight it will add a credit for payout
            }
        }
        // The credited amount for the relevant flight will be added to the total payout of the insuree
        payouts[insuree] = payouts[insuree].add(creditedAmount); 

    }
    
    /**
     *  @dev Transfers eligible payout funds to insuree, they can call this to withdraw funds
     *
    */
    function pay
                            (
                                address insuree
                            )
                            external
                            
    {

        uint256 creditedAmount = payouts[insuree];
        // Checks -> Credit checked in app contract
        // Effects
        payouts[insuree] = 0; // Debit
        // Interaction
        insuree.transfer(creditedAmount); // Credit
        delete payouts[insuree]; //removes the asset
    }

// PASSENGER HANDLING ends ------

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable
    {
        fundAirline(msg.sender);
    }


}

