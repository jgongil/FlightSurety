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

    //Restrict Data Contract Callers
     mapping(address => uint256) private authorizedContracts;

    //Airline funds
    mapping(address => uint256) internal airlineFunds;

    uint256 public constant AIRLINE_MIN_FUND = 10 ether;
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        // First airline gets registered as admin
        airlineProfiles[firstAirline] = AirlineProfile({
                                                    isRegistered: true,
                                                    isFunded: false
                                                     });                                                
    }

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

    function isAirlineFunded(
                            address airline
                            )
                            external
                            view
                            returns(bool)
    {
        return airlineProfiles[airline].isFunded;
    }
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
                            requireContractOwner
    {
        require(!airlineProfiles[wallet].isRegistered, "Airline is already registered.");

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
        require(airlineProfiles[airline].isRegistered);

        //uint256 currentBalance = airlineFunds[airline];
        uint256 input = msg.value; // funds sent in wei
        airlineFunds[airline].add(input);

        // mark airline as funded if it reaches the minimun funds        
        if ((airlineFunds[airline] > AIRLINE_MIN_FUND) && !airlineProfiles[airline].isFunded){
            airlineProfiles[airline].isFunded = true;
        }
    }
// AIRLINES MANAGEMENT ends

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (                             
                            )
                            external
                            payable
    {

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
     *  @dev Transfers eligible payout funds to insuree
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
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

