pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;
    uint private airlinesRegisteredCount;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    uint256 private enabled = block.timestamp;
    uint256 private counter = 1;

    struct Airline {
        bool isRegistered;    
        bool isFunded;  
        string airlineName;
    }

    struct Flight {
        string flightName;
        address airline;
        uint8 statusCode;
        uint256 timestamp;
    }

    struct Insurance {
        address passenger;
        uint256 insuranceAmount;
    }

    mapping(address => Airline) private airlines;
    mapping(bytes32 => Flight) private flights;
    mapping(bytes32 => Insurance[]) insuredPassengersPerFlight;
    mapping(address => uint) public pendingPayments;
    mapping(address => uint256) private authorizedContracts;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    string memory name, 
                                    address airlineAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        registerAirline(name, airlineAddress);
    }

    mapping(address => Airline) registeredAirlines;
    mapping(address => uint8) authorizedCallers;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event InsuranceBought(address airline, string flight, uint256 timestamp, address passenger, uint256 amount, uint256 multiplier);
    event FlightStatusUpdated(address airline, string flight, uint256 timestamp, uint8 statusCode);
    event AirlineRegistered(string name, address addr);
    event AirlineFunded(string name, address addr);
    event FlightRegistered(bytes32 flightKey, address airline, string flight, string from, string to, uint256 timestamp);
    event InsureeCredited(address passenger, uint256 amount);
    event AccountWithdrawn(address passenger, uint256 amount);

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

    modifier airlineDoesNotExist()
    {
        require(!registeredAirlines[airlineAddress], "This Airline does not exist");
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
    {
        operational = mode;
    }

    /**
   * @dev Get airline details
   *
   * @return Airline with the provided address
   */
  function getAirlineName(address airline) external view returns(string memory) {
    return airlines[airline].name;
  }

  /**
   * @dev Check if the address is a registered airline
   *
   * @return A bool confirming whether or not the address is a registered airline
   */
  function isAirline(address airline) external view returns(bool) {
    return airlines[airline].isRegistered;
  }

  /**
   * @dev Check if the address is a funded airline
   *
   * @return A bool confirming whether or not the address is a funded airline
   */
  function isFundedAirline(address airline) external view returns(bool) {
    return airlines[airline].isFunded;
  }

  /**
   * @dev Get registered airlines
   *
   * @return An array with the addresses of all registered airlines
   */
  function getRegisteredAirlines() external view returns(address[] memory) {
    return registeredAirlines;
  }

  /**
   * @dev Check if the flight is registered
   */
  function getFlightStatusCode(address airline, string calldata flight, uint256 timestamp) external view returns(uint8) {
    return flights[getFlightKey(airline, flight, timestamp)].statusCode;
  }

  /**
   * @dev Check if the flight is registered
   */
  function isFlight(address airline, string calldata flight, uint256 timestamp) external view returns(bool) {
    return flights[getFlightKey(airline, flight, timestamp)].isRegistered;
  }

  /**
   * @dev Check if the flight status code is "landed"
   */
  function isLandedFlight(address airline, string calldata flight, uint256 timestamp) external view returns(bool) {
    return flights[getFlightKey(airline, flight, timestamp)].statusCode > STATUS_CODE_UNKNOWN;
  }

  /**
   * @dev Check if the passenger is registerd for the flight
   */
  function isInsured(address passenger, address airline, string calldata flight, uint256 timestamp) external view returns (bool) {
    Insurance[] memory insuredPassengers = insuredPassengersPerFlight[getFlightKey(airline, flight, timestamp)];
    for(uint i = 0; i < insuredPassengers.length; i++) {
      if (insuredPassengers[i].passenger == passenger) {
        return true;
      }
    }
    return false;
  }

  /**
   * @dev Return the pending payment
   */
  function getPendingPaymentAmount(address passenger) external view returns (uint256) {
    return pendingPayments[passenger];
  }

  /**
   * @dev Sets contract operations on/off
   *
   * When operational mode is disabled, all write transactions except for this one will fail
   */    
  function setOperatingStatus(bool mode) external requireContractOwner {
    require(mode != operational, "New mode must be different from existing mode");

    bool isDuplicate = false;

    for(uint i = 0; i < multiCalls.length; i++) {
      if (multiCalls[i] == msg.sender) {
        isDuplicate = true;
        break;
      }
    }

    require(!isDuplicate, "Caller has already called this function.");

    multiCalls.push(msg.sender);

    if (multiCalls.length >= M) {
      operational = mode;
      multiCalls = new address[](0);
    }
  }

  /**
   * @dev Adds address to authorized contracts
   */
  function authorizeCaller(address contractAddress) external requireContractOwner {
    authorizedContracts[contractAddress] = 1;
  }

  /**
   * @dev Removes address from authorized contracts
   */
  function deauthorizeCaller(address contractAddress) external requireContractOwner {
    delete authorizedContracts[contractAddress];
  }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function registerAirline(string calldata name,
                             address airlineAddress) external {
            require(!registeredAirlines[airlineAddress].isRegistered, "This Airline has already been registered");

            registeredAirlines[airlineAddress] = Airline({
                airlineName: name,
                isFunded: false, 
                isRegistered: true
            });

            airlinesRegisteredCount.push(airlineAddress);

            emit AirlineRegistered(name, addr);
    }


  function fundAirline(address airlineAddress) external airlineDoesNotExist {
    require(!registeredAirlines[airlineAddress].isFunded, "This Airline has already been funded");
      
    registeredAirlines[airlineAddress].isFunded = true;
    emit AirlineFunded(registeredAirlines[airlineAddress].name, registeredAirlines);
  }


  function registerFlight(address airline, string calldata flight, string calldata from, string calldata to, uint256 timestamp) external requireIsOperational requireIsCallerAuthorized requireValidAddress(airline) requireAirlineIsFunded(airline) {
    bytes32 flightKey = getFlightKey(airline, flight, timestamp);
    require(!flights[flightKey].isRegistered, "Flight has already been registered");

    flights[flightKey] = Flight({
      isRegistered: true,
      statusCode: 0,
      updatedTimestamp: timestamp,
      airline: airline,
      flight: flight,
      from: from,
      to: to
    });

    registeredFlights.push(flightKey);

    emit FlightRegistered(flightKey, airline, flight, from, to, timestamp);
  }

  function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external requireIsOperational requireIsCallerAuthorized {
    bytes32 flightKey = getFlightKey(airline, flight, timestamp);    
    
    if (flights[flightKey].statusCode == STATUS_CODE_UNKNOWN) {
      flights[flightKey].statusCode = statusCode;
      if(statusCode == STATUS_CODE_LATE_AIRLINE) {
        creditInsurees(airline, flight, timestamp);
      }
    }

    emit FlightStatusUpdated(airline, flight, timestamp, statusCode);
  }

   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy
                            (    
                                address airline, 
                                string calldata flight,
                                uint256 timestamp,
                                address passenger,
                                uint256 amount,
                                uint256 multiplier                         
                            )
                            external
                            payable
                            isOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        insuredPassengersPerFlight[flightKey].push(Insurance({
            passenger: passenger,
            amount: amount,
            multiplier: multiplier,
            isCredited: false
        }));

        emit InsuranceBought(airline, flight, timestamp, passenger, amount, multiplier);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp
                                )
                                external
                                pure
                                isOperational
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        for (uint i = 0; i < insuredPassengersPerFlight[flightKey].length; i++) {
        Insurance memory insurance = insuredPassengersPerFlight[flightKey][i];

        if (insurance.isCredited == false) {
            insurance.isCredited = true;
            uint256 amount = insurance.amount.mul(insurance.multiplier).div(100);
            pendingPayments[insurance.passenger] += amount;

            emit InsureeCredited(insurance.passenger, amount);
        }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                                address passenger
                            )
                            external
                            pure
                            isOperational
    {
        require(passenger == tx.origin, "Contracts not allowed");
        require(pendingPayments[passenger] > 0, "No fund available for withdrawal");
        
        uint256 amount = pendingPayments[passenger];
        pendingPayments[passenger] = 0;

        address passengerAddress = address(uint160(passenger));
        passengerAddress.transfer(amount);

        emit AccountWithdrawn(passenger, amount);
    }

  function getFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) {
    return keccak256(abi.encodePacked(airline, flight, timestamp));
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
                            isOperational
    {
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable
                            isOperational 
    {
        fund();
    }


}

