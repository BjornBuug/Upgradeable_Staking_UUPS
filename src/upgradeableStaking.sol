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
import "./Math.sol";




/// @title Staking Smart Contract
/// @notice A UUPS (Universal Upgradeable Proxy Standard) compliant smart contract that enables users to stake, unstake, and claim tokens.
/// @author Ouail Tayarth
/// @dev The contract is upgradeable and includes pausability features.

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
    error ERR_CALLER_NOT_STAKER();
    error ERR_ADDRESS_CANNOT_BE_ZERO();
    error ERR_AMOUNT_BELOW_MIN();
    error ERR_NOT_ENOUGH_BALANCE();
    error ERR_FROM_CALCULATION();


    //***************************** EVENTS ************/
    event Staked(address indexed staker,
                 uint256 indexed amount,
                 uint256 indexed timeStamp); 

    event Unstaked(address indexed staker,
                 uint256 indexed amount,
                 uint256 indexed timeStamp);

    event Claimed(address indexed claimAmt,
                  uint256 indexed amount,
                  uint256 indexed timeStamp);             


    uint256 public totalStakedTokens;

    // Keep track of all stakers Info
    struct StakerInfo {
        address staker;
        uint256 amountStaked;
        uint256 lastRewardTimestamp;
        uint256 debtRewards;
    }

    mapping (address => StakerInfo) public stakers;

    uint256 public rewardsPerToken;
    uint256 public rewardsEndTime;
    uint256 public rewardsStartTime;
    uint256 public lastUpdateTime;
    uint256 public rewardRate;
    
    mapping (address => uint256) public userRewardsPerTokensPaid;
    uint public constant MIN_AMOUNT_TO_STAKE = 10_000_000_000_000_000_000; // Min amount 10 token to stake


    // ///@dev To prevent an attacker to Initialize the contract when the contract is deployed and unInitilize
    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() {
    //     _disableInitializers();
    // }


    /// @dev Modifier to check if the caller is a staker.
    modifier onlyStakers() {
        if(stakers[msg.sender].staker != msg.sender) {
            revert ERR_CALLER_NOT_STAKER();
        }
        _;
    }

    modifier nonZeroValue(uint256 _amount) {
        if(_amount <= 0) {
            revert ERR_CANNOT_BE_ZERO();
        }
        _;
    }

    modifier IsZeroAddress() {
        if(msg.sender == address(0)) {
            revert ERR_ADDRESS_CANNOT_BE_ZERO();
        }
        _;
    }


    /// @notice Initializes the staking contract.
    /// @param _token The ERC20 token for staking.
    function initilize(IERC20Upgradeable _token) initializer public {  
        __Ownable_init();
        __ERC20Pausable_init();
        __ERC20_init("Staking TK", "TTK");
        token = _token;
    }


    /// @notice Stakes tokens into the contract.
    /// @param _amount The amount of tokens to stake.
     function Stake(uint256 _amount) external 
                                    whenNotPaused
                                    IsZeroAddress
                                    {
        
        if(_amount < MIN_AMOUNT_TO_STAKE) {
            revert ERR_AMOUNT_BELOW_MIN();
        }
                                       
        StakerInfo storage stakerInfo = stakers[msg.sender];
        
        rewardsHandler(stakerInfo);

        stakerInfo.staker = msg.sender;
        stakerInfo.amountStaked += _amount;
        totalStakedTokens += _amount;

        token.safeTransferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount, block.timestamp);

    }
    


    // Check the Staker want to unstack more than they own.
    /// @notice Unstakes tokens
    /// @param _amount The amount of tokens to unstake.
     function Unstake(uint256 _amount) external 
                                             onlyStakers
                                                 nonZeroValue(_amount) {
        
        StakerInfo storage stakerInfo = stakers[msg.sender];

        uint256 amountStaked = stakerInfo.amountStaked;

        if(_amount > amountStaked) {
            revert ERR_NOT_ENOUGH_BALANCE();
        }

        rewardsHandler(stakerInfo);

        amountStaked-= _amount;
        stakerInfo.amountStaked =  amountStaked;
        totalStakedTokens -= _amount;

        token.safeTransfer(msg.sender, _amount);

        emit Unstaked(msg.sender, _amount, block.timestamp);
    }



    /// @notice Claim Rewards
     function Claim() external onlyStakers {

        StakerInfo storage stakerInfo = stakers[msg.sender];

        uint256 claimedRewards = stakerInfo.debtRewards;

        rewardsHandler(stakerInfo);

        stakerInfo.debtRewards = 0;

        _mint(msg.sender, claimedRewards);

        emit Claimed(msg.sender, claimedRewards, block.timestamp);
    }



    /// @notice Set & Updates the rewards rate and _duration.
    /// @param _amount The total rewards amount.
    /// @param _duration The rewards duration in seconds.
   function setRewards(uint256 _amount, uint256 _duration) external onlyOwner {
        
        // Check if the contract isn't giving rewards any more to be able to start a new update;
        if(rewardsEndTime > block.timestamp) {
            revert ERR_CANNOT_UPDATE_REWARDS_YET();
        }

        if(_amount <= 0 || _duration <= 0) {
            revert ERR_CANNOT_BE_ZERO();
        }

        rewardsEndTime = block.timestamp + _duration;
        rewardRate = _amount / _duration;
        lastUpdateTime = block.timestamp;
        rewardsStartTime = block.timestamp;
   }
    

    /// @dev Handles rewards calculations.
    /// @param stakerInfo The staker's information.
    /// @return totalPendingRewards The total pending rewards for the staker.
    function rewardsHandler(StakerInfo storage stakerInfo) internal returns(uint256 totalPendingRewards) {
        // Check if the contract has staked tokens
        if(totalStakedTokens > 0) {
            // Create a function to calculate the user pending rewards and new rewards per tokens since the last time the user checked.
            (uint256 _totalPendingRewards, uint256 newRewardsPerToken) = calculateRewards(stakerInfo, msg.sender);

            // Update the total rewards tokens for msg.sender
            totalPendingRewards = _totalPendingRewards;
            
            // Update the new rewards per tokens
            rewardsPerToken = newRewardsPerToken;

            userRewardsPerTokensPaid[msg.sender] = rewardsPerToken; 
        }

        lastUpdateTime = _lastApplicableTime();

        // Update staker info
        stakerInfo.debtRewards += totalPendingRewards;
        stakerInfo.lastRewardTimestamp = block.timestamp;
    }

    
    /// @notice newRewardsPerToken is Dynamic which means it's updated based on the amount of staked tokens.
    /// @notice newRewardsToken represents the the amount of tokens the user has accumuled and didn't claimed yet. 
    /// @dev Calculates rewards for a given staker.
    /// @param stakerInfo The staker's information.
    /// @param _staker The address of the staker.
    function calculateRewards(StakerInfo storage stakerInfo, address _staker) 
                              internal view returns(uint256 totalPendingRewards, uint256 newRewardsPerToken) {

            if(totalStakedTokens > 0) {

            /*** @notice - (rewardRate * (_lastApplicableTime() - lastUpdateTime)): Calculate how much rewards has been accumulated since
                            the last applicable time.
                         - * 1 ether is to add more zero (18 decimals)
                         - / totalStaked gives the per-tokens reward
                         - rewardsPerToken + "adding the newly calculated per-token rewards" to the existing per token rewards;        
            */  
            // How much new reward is earn per tokens since our "last Applicable" "time" & "rate update"
            // or How much more rewards each token should get
            // Check overflow and underflow checks
            if(_lastApplicableTime() >= lastUpdateTime) {
                newRewardsPerToken = rewardsPerToken + (( rewardRate * (_lastApplicableTime() - lastUpdateTime)) * 1 ether) / totalStakedTokens;
                       
            /***
            *  - newRewardPerToken - userRewardPerTokenPaid[_staker]: How much reward per token Bob has earned since the last time he checked.
            *  - stakerInfo.stakedAmount * : Multiplties Bob's staked tokens by the newRewardPerToken to find out Bob's total new rewards.
            *  - divide it by 1 ether to back down to normal number because we multiple above by 1 ether
            */

            require(newRewardsPerToken >= userRewardsPerTokensPaid[_staker], "Error: Negative rewards");

            // How much new rewards Bob has earned on his staked since last time he checked (rewards rate, last timeStamp)
            // Or how much new rewards Bob has earned.
            totalPendingRewards = (stakerInfo.amountStaked * (newRewardsPerToken - userRewardsPerTokensPaid[_staker])) * 1 ether;
            
            }
            else revert ERR_FROM_CALCULATION();
        }                                                                  

    }


    //***************  Getters    ******************/

     /// @notice Returns the total pending rewards for a staker.
    /// @param _stakerAddress The address of the staker.
    /// @return totalPendingRewards The total pending rewards for the staker.
    function getAllPendingRewards(address _stakerAddress) external IsZeroAddress view returns(uint256 totalPendingRewards) {
        StakerInfo storage stakerInfo = stakers[_stakerAddress];
        (totalPendingRewards,) = calculateRewards(stakerInfo, _stakerAddress);
    }


    /// @notice Returns the staker's information.
    /// @param _stakerAddress The address of the staker.
    /// @return StakerInfo The staker's information.
    function getStakerInfo(address _stakerAddress) external IsZeroAddress view returns(StakerInfo memory) {
        return stakers[_stakerAddress];
    }



    /// @dev Returns the last time rewards can be applicable.
    /// @return The last time rewards can be applicable, which is the minimum of current block timestamp and the rewards end time.
    function _lastApplicableTime() public view returns (uint256) {
        return Math.min(block.timestamp, rewardsEndTime);
    }

    // function min(uint x, uint y) internal pure returns (uint z) {
    //     z = x < y ? x : y;
    // }

    /// @notice Pauses the contract functionalities.
    /// @dev Can only be called by the contract owner.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract functionalities.
    /// @dev Can only be called by the contract owner.
    function unpause() external onlyOwner {
        _unpause();
    }


    /// @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by {upgradeToAndCall}.
    function _authorizeUpgrade(address) internal override onlyOwner() {}

}