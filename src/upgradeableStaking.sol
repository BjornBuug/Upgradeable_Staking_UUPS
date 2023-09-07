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
                  - create a function to updateRewards() & claimRewards [x]
                  - To do: Override pause and unpause functions +  Getters(getPendingRewards function + getStaker Info function)

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
    error ERR_CANNOT_BE_ZERO();
    error ERR_CANNOT_UPDATE_REWARDS_YET();



    //***************************** EVENTS ************/
    event Staked(address indexed staker,
                 uint256 indexed amount,
                 uint256 indexed timeStamp); // What is indexed and why it used for.

    event Unstaked(address indexed staker,
                 uint256 indexed amount,
                 uint256 indexed timeStamp);

    event Claimed(address indexed claimAmt,
                  uint256 indexed amount,
                  uint256 indexed timeStamp;             


    uint256 public totalStakedTokens;

    // Keep track of all stakers Info
    struct StakerInfo {
        uint256 amountStaked;
        uint256 lastTimestamp; // Last time the staker stakes tokens.
        uint256 DebtRewards;
    }

    mapping (address => StakerInfo) public stakers;
    
    uint256 public rewardsPerToken;
    uint256 public rewardsEndTime;
    uint256 public rewardsStartTime;
    uint256 public lastUpdateTime;
    uint256 public rewardsRate;
    
    mapping (address => uint256) public userRewardsPerTokensPaid;
    


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
     function stake(uint256 _amount) external whenNotPaused {
        if(_amount <= 0) {
            revert ERR_CANNOT_BE_ZERO();
        }

        StakerInfo storage staker = stakers[msg.sender];
        
        rewardsHandler(staker);

        staker.amountStaked += _amount;
        totalStakedTokens += _amount;

        token.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount, block.timestamp);

    }
    
   }


   /**
     * @dev Function to stake tokens
     * @param _amount amount of stake tokens
     * 
     */
     // @audit-issue check if the caller is the staker
     function UnstakeAndClaim(uint256 _amount) external whenNotPaused {
        if(_amount <= 0) {
            revert ERR_CANNOT_BE_ZERO();
        }

        StakerInfo storage staker = stakers[msg.sender];
        uint256 amountStaked = staker.amountStaked;
        uint256 claimedRewards = staker.rewardDebt;

        rewardsHandler(staker);

        amountStaked-= _amount;
        totalStakedTokens -= _amount;

        token.safeTransfer(msg.sender, _amount);

        // ** Claim rewards **/
         claimedRewards = 0; 
        _mint(msg.sender, claimedRewards);// Let check the security aspect of including Claim in this function.

        emit Unstaked(msg.sender, _amount, block.timestamp);
        emit Claimed(msg.sender, claimedRewards, block.timestamp);

    }
    

   ///@notice function that allow to update rewards rate & rewardsEndTime & rewardsstarttime
   function updateRewards(uint256 _amount, uint256 duration) external onlyOwner {
        
        // Check if the contract isn't giving rewards any more to be able to start a new update;
        if(rewardsEndTime > block.timestamp) {
            revert ERR_CANNOT_UPDATE_REWARDS_YET();
        }

        if(_amount <= 0 || duration <= 0) {
            revert ERR_CANNOT_BE_ZERO();
        }

        rewardsEndTime = block.timestamp + duration;
        rewardsRate = _amount / duration;
        lastUpdateTime = block.timestamp;
        rewardsStartTime = block.timestamp;

   }
    


    /**
     * @notice The reason why we have "pending rewards" because it will allow users to withdraw pending rewards if the contract is not dynamic or pausable
     * @dev Function to handle rewards
     * @param _amount amount of stake tokens
     */
    function rewardsHandler(stakerInfo storage stakerInfo) internal returns(uint256 totalPendingRewards) {
        // Check if the the the contract has staked tokens
        if(totalStakedTokens > 0) {
            // Create a function to calculate the user pending rewards and new rewards per tokens since the last time the user checked.
            (uint256 _totalPendingReward, uint256 newRewardsPerToken) = calculateRewards(stakerInfo, msg.sender);

            // Update the total rewards tokens for msg.sender
            totalPendingRewards = _totalPendingReward;

            // Update the new rewards per tokens
            rewardsPerToken = newRewardsPerToken;

            userRewardsPerTokensPaid[msg.sender] = rewardsPerToken; 
        }

        lastUpdateTime = _lastApplicableTime();

        // Update staker info
        stakerInfo.amountStaked += totalPendingRewards;
        stakerInfo.lastTimestamp += block.timestamp;
    }




    function calculateRewards(StakerInfo storage stakerInfo, address _staker) 
                              internal returns(uint256 totalPendingRewards, uint256 newRewardsPerToken) {

            if( totalStakerTokens > 0) {

            /*** @notice - (rewardRate * (_lastApplicableTime() - lastUpdateTime)): Calculate how much rewards has been accumulated since
                            the last applicable time.
                         - * 1 ether is to add more zero (18 decimals)
                         - / totalStaked gives the per-tokens reward
                         - rewardsPerTokens + "adding the newly calculated per-token rewards" to the existing per token rewards;        
            */  
            // How much new reward is earn per tokens since our "last Applicable" "time" & "rate update"
            // or How much more rewards each token should get
            newRewardsPerToken = rewardsPerToken + (( rewardRate * (_lastApplicableTime() - lastUpdateTime)) * 1 ether) / totalStakedTokens;


            /***
            *  - newRewardPerToken - userRewardPerTokenPaid[_staker]: How much reward per token Bob has earned since the last time he checked.
            *  - stakerInfo.stakedAmount * : Multiplties Bob's staked tokens by the newRewardPerToken to find out Bob's total new rewards.
            *  - divide it by 1 ether to back down to normal number because we multiple above by 1 ether
            */

            // How much new rewards Bob has earned on his staked since last time he checked (rewards rate, last timeStamp)
            // Or how much new rewards Bob has earned.
            totalPendingRewards = (stakerInfo.stakedAmount * (newRewardPerToken - userRewardPerTokenPaid[msg.sender])) * 1 ether;

            }                                                               

    }


    function _lastApplicableTime() returns view internal(uint256) {
        Math.min(block.timestamp, rewardsEndTime);
    }

