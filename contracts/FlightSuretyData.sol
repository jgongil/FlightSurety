pragma solidity ^0.4.25;

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

    // Fees for airlines to join
    uint256 public constant JOIN_FEE = 10 ether;


    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    // Flight insurance assets wallet: (Flight+Passenger) -> assetId -> balance
    mapping(bytes32 => uint256) insuranceAssetWallet;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


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

//MODIFIERS START

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
        require(authorizedContracts[msg.sender] == 1, "Caller is not contract owner");
        _;
    }

//MODIFIERS END

//UTILITY FUNCTIONS START
    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

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
                            bytes32 flightCode
                            )
                            external
                            view
                            returns(bool)
    {
        return flights[flightCode].isRegistered;
    }

//UTILITY FUNCTIONS END

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

// AIRLINES MANAGEMENT starts
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
    {
        require(!airlineProfiles[wallet].isRegistered, "Airline is already registered.");

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
        require(airlineProfiles[airline].isRegistered, "Airline is not registered so cannot be funded"); // The airline must be registered already as first step

        airlineFunds[airline] = airlineFunds[airline].add(msg.value); // Keep record of contributions of every company

        // mark airline as funded if it is not, and the value reaches the JOIN_FEE        
        if ((airlineFunds[airline] >= JOIN_FEE) && !airlineProfiles[airline].isFunded){
            airlineProfiles[airline].isFunded = true;
        }
    }
// AIRLINES MANAGEMENT ends

    /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    bytes32 flightCode,
                                    uint8 statusCode,
                                    uint256 updatedTimestamp,
                                    address airline
                                )
                                external
                                requireIsOperational
                                requireIsCallerAuthorized
    {
        flights[flightCode] = Flight({
                                        isRegistered: true,
                                        statusCode:statusCode,
                                        updatedTimestamp:updatedTimestamp,
                                        airline: airline

                                    });
    }

   /**
    * @dev Buy insurance for a flight: Passenger buys insurance based on flight code.
    *
    */   
    function buy
                            (
                                address buyer,
                                bytes32 flightCode
                            )
                            external
                            payable
                            requireIsOperational
    {
        bytes32 insuranceKey = keccak256(abi.encodePacked(buyer, flightCode));
        insuranceAssetWallet[insuranceKey] = msg.value;
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                pure
    {
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree, they can call this to withdraw funds
     *
    */
    function pay
                            (
                            )
                            external
                            pure
    {
        
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
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

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() external payable
    {
        fundAirline(msg.sender);
    }


}

