// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @dev This Library contains Initializer modifier to ensure than the Initialize function can only be called once (like the constructor)
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
/// @dev To ensure that ERC20 token is upgradeable.
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

// should be Initialize inside the Initialize function/Constructor
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";




/**
    Project Rebuild plan:
                  - Important Interfaces and understand each one them and what it purposes [x] 
                  - Initialize the contract [x]
                  - 

 */


/// @notice This is a UUPS smart contract that allow user to stake tokens and get rewarded.


contract UpgradableStaking is Initializable,
        OwnableUpgradeable,
        ERC20PausableUpgradeable,
        UUPSUpgradeable {

    // Using is solidity keyword that allow to attack Library with a data type.
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable public token;


    ///@dev To prevent an attacker to Initialize the contract when the contract is deployed and unInitilize
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    /// @dev Initialize function that runs only once
    function Initilize(IERC20Upgradeable _token) external initializer  {  
        __Ownable_init();
        __ERC20Pausable_init();
        __ERC20_init("Staking TK", "TTK");
        token = _token;
    }

}