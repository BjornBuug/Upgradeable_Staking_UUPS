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




/** "BUILD FROM SMALL FEATURES TO COMPLEX one"
    Project Rebuild plan:
                  - Important Interfaces and understand each one them and what it purposes [x] 
                  - Initialize the contract [x]
                  - Stake functions & unStake Functions.
                  - What State variables do we need to create stake & unstake functions:
                  1- Keep track of all staked tokens. [x]
                  2- Keep track of all stakers deposits & withdraw, to do so: we need to create a mapping from msg.sender => struct
                  The struct will contain the stakers info to update [x]
                  - create functions

 */


/// @notice This is a UUPS smart contract that allow user to stake tokens and get rewarded.


contract UpgradeableStaking is Initializable,
        OwnableUpgradeable,
        ERC20PausableUpgradeable,
        UUPSUpgradeable {

    // Using is solidity keyword that allow to attack Library with a data type.
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable public token;


    //***************************** ERROR ************/
    error cannotBeZero();


    //***************************** EVENTS ************/
    event Staked(address indexed staker,
                 uint256 indexed amount,
                 uint256 indexed timestamp);

    event Unstaked(address indexed staker,
                 uint256 indexed amount,
                 uint256 indexed timestamp);


    uint256 public totalStakedTokens;

    // Keep track of all stakers Info
    struct StakerInfo {
        uint256 amountStaked;
        uint256 LastTimestamp; // Last time the staker stakes tokens.
        uint256 DebtRewards;
    }

    mapping (address => StakerInfo) public stakers;
    


    ///@dev To prevent an attacker to Initialize the contract when the contract is deployed and unInitilize
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }


    /// @dev Initialize function that runs only once
    function initilize(IERC20Upgradeable _token) external initializer {  
        __Ownable_init();
        __ERC20Pausable_init();
        __ERC20_init("Staking TK", "TTK");
        token = _token;
    }


    /**
     * @dev Function to stake tokens
     * @param _amount amount of stake tokens
     * 
     */
     function stake(uint256 _amount) external {
        if(_amount <= 0) {
            revert cannotBeZero();
        }

        StakerInfo storage staker = stakers[msg.sender];

        staker.amountStaked += _amount;
        totalStakedTokens += _amount;

        // Handle rewards function

        token.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount, block.timestamp);

    }
    
}








    // The reason why we have "pending rewards" because it will allow users to withdraw pending rewards if the contract is not dynamic or pausable
/// @dev Calculates the rewards and handles them (updating states and transfering them if "autocompound" is enabled)
    /// @param staker The staker info
    /// @return pendingReward The pending rewards
    function _handleRewards(
        StakerInfo storage staker
    ) internal returns (uint256 pendingReward) {
        /// @dev We need this check here because if totalStaked is 0 and the first ever staker wants to stake,
        /// @dev calculation will fail because the formula includes division by totalStaked
        if (totalStaked > 0) {
            
            // @audit Calculating users pending "rewards" and the "newRewardsPerToken"
            (
                uint256 _pendingReward,
                uint256 newRewardPerToken
            ) = _calculatePendingRewards(staker, msg.sender);

            // @audit Updating users "pending rewards" and the "newRewardsPerToken"
            pendingReward = _pendingReward;
            rewardPerToken = newRewardPerToken;

            // Updating the paid rewards paid for users
            userRewardPerTokenPaid[msg.sender] = rewardPerToken;
        }

        lastUpdateTime = _lastApplicableTime();

        staker.rewardDebt += pendingReward;
        staker.lastRewardTimestamp = block.timestamp;
    }



    /// @dev calculating the pending rewards and the new reward per token if the contract is dynamic
    /// @param stakerInfo The staker info
    /// @param _staker The address of the staker
    /// @return totalReward The pending rewards
    /// @return newRewardPerToken The pending rewards
    function _calculatePendingRewards(
        StakerInfo storage stakerInfo,
        address _staker
    ) internal view returns (uint256 totalReward, uint256 newRewardPerToken) {
        
        if (totalStaked > 0) {
            /*** @notice - (rewardRate * (_lastApplicableTime() - lastUpdateTime)): Calculate how much rewards has been accumulated since
                            the last applicable time.
                         - * 1 ether is to add more zero (18 decimals)
                         - / totalStaked gives the per-tokens reward
                         - rewardsPerTokens + "adding the newly calculated per-token rewards" to the existing per token rewards;        
             */
            // How much new reward is earn per tokens since our "last Applicable" "time" & "rate update"
            // or How much more rewards each token should get
            newRewardPerToken = rewardPerToken + ((rewardRate * (_lastApplicableTime() - lastUpdateTime)) * 1 ether) / totalStaked;
        }

        /***
           *  - newRewardPerToken - userRewardPerTokenPaid[_staker]: how much reward per token Bob has earned since the last time he checked.
           *  - stakerInfo.stakedAmount * : Multiplties Bob's staked tokens by the newRewardPerToken to find out Bob's total new rewards.
           *  - divide it by 1 ether to back down to normal number because we multiple above by 1 ether
        */

        // How much new rewards Bob has earned on his staked since last time he checked (rewards rate, last timeStamp)
        // Or how much new rewards Bob has earned.
        totalReward =
            (stakerInfo.stakedAmount *
                (newRewardPerToken - userRewardPerTokenPaid[_staker])) /
            1 ether;
    }


    /// @dev When calculating rewards, we want to don't want to include the current timestamp
    /// @dev in the calculations if the contract isn't giving out rewards anymore.
    /// @dev Returns the last applicable time based on the current time and the finish time of giving rewards.
    /// @return The last applicable time.
    function _lastApplicableTime() internal view returns (uint) {
        return Math.min(block.timestamp, rewardFinishAt);
    }