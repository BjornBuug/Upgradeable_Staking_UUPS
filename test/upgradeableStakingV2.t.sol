// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;


import "forge-std/Test.sol";
import "forge-std/console2.sol";


import "../src/FaucetTokens.sol";
import "./contracts/upgradeableStakingV2.sol";

contract upgradeableStakingV2V2Test is Test {
    using stdStorage for StdStorage;

    // Stake [x]
    // Unstake []


    // Initial Faucet Supply
    uint256 public constant INITIAL_TOKENS_SUPPLY = 100000000 ether;
    uint256 public constant COOL_DOWN_PERIOD = 60;
    uint256 public constant AMOUNT_TO_WITHDRAW = 10 ether;
    uint256 public constant REWARD_DURATION = 48600; /// 1 days
    uint256 public constant REWARD_AMOUNT = 10 ether;

    // Create an instances of the contracts
    upgradeableStakingV2 public staking;
    FaucetTokens public token;
    
    address constant public ALICE = address(0x1);
    address constant public BOB = address(0x2);
    address constant public ADMIN = address(0x3);

    // Setting up 
    function setUp() public {
        vm.startPrank(ADMIN);

        staking = new upgradeableStakingV2();

        // Initialize the token faucet
        token = new FaucetTokens(
            INITIAL_TOKENS_SUPPLY,
            COOL_DOWN_PERIOD,
            AMOUNT_TO_WITHDRAW
        );

        vm.label(ALICE, "ALICE");
        vm.label(BOB, "BOB");
        vm.label(ADMIN, "ADMIN");

        token.transfer(address(ALICE), 1000 ether);
        token.transfer(address(BOB), 1000 ether);
        
        console2.log("ALICE balance", token.balanceOf(ALICE));

        staking.initilize(IERC20Upgradeable(address(token)));

        vm.warp(10800); // 3 HOURS

        staking.setRewards(REWARD_AMOUNT, REWARD_DURATION);

        vm.stopPrank();
    }



    function test_Stake() public {
        vm.startPrank(ALICE);

        // vm.warp(1695474145);  // now
        // // Returns values to check for overflow or underflow cases:
        // uint256 lastApplicableTime = staking._lastApplicableTime();
        // console2.log("lastApplicable time before Staking", lastApplicableTime);
        // uint256 lastUpdateTime = staking.lastUpdateTime();
        // console2.log("Last Update Time before staking", lastUpdateTime);
        
        console2.log("current Time before staking", block.timestamp);
            
            // Amount to Stake
            uint256 amount = 100 ether;
            token.approve(address(staking), amount);

            // Stake
            staking.Stake(amount);

            // Get Staker Info
            upgradeableStakingV2.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);
            assertEq(stakerInfo.staker, ALICE);
            assertEq(stakerInfo.amountStaked, amount);
            assertEq(token.balanceOf(address(staking)), amount);
            assertEq(staking.totalStakedTokens(), amount);

            // // Returns values to check for overflow or underflow cases:
            // lastApplicableTime = staking._lastApplicableTime();
            // console2.log("lastApplicable time after Staking", lastApplicableTime);

            // lastUpdateTime = staking.lastUpdateTime();
            // console2.log("Last Update Time after staking", lastUpdateTime);
            
            // console2.log("Current time after staking", block.timestamp);
        vm.stopPrank(); 

    }

    //************* EXPECT REVERT ************/
    function test_revert_Paused_Contract() public {
        vm.startPrank(ADMIN);
            staking.pause();
        vm.stopPrank();

        // // Try to Stake when the contract is paused
        // test_Stake();
        // vm.expectRevert("Pausable: paused");

        // Try to UnStake when the contract is paused
        test_Unstake();
        vm.expectRevert("Pausable: paused");
    }

    function test_revert_Stake_Amount_Below_MIN() public {
        vm.startPrank(ALICE);
            // Test below Minimum 
            uint256 amount = 0.00001 ether;
            staking.Stake(amount);
            vm.expectRevert(upgradeableStakingV2.ERR_AMOUNT_BELOW_MIN.selector);
        vm.stopPrank();
    }


    function test_revert_Stake_Zero_Address() public {
        vm.startPrank(address(0));
            // Test below Minimum 
            uint256 amount = 10 ether;
            staking.Stake(amount);
            vm.expectRevert(upgradeableStakingV2.ERR_ADDRESS_CANNOT_BE_ZERO.selector);
        vm.stopPrank();
    }


    /****************** Unstake Units Test  *********************** */
    // Unstake
    function test_Unstake() public {
        test_Stake();
        vm.startPrank(ALICE);

            
   
            // Get Alice Balance Before unstaking:
            uint256 AliceBalBef = token.balanceOf(address(ALICE));
            console2.log("Alice balance before", AliceBalBef);

            skip(REWARD_DURATION);


            // uint256 totalPendingRewards = staking.rewardsHandler(stakerInfo);
            // console2.log("Alice's total Pending", totalPendingRewards);
            
            // uint256 newRewardsPerToken = staking.rewardsPerToken();
            // console2.log("New rewardsPerTokens", newRewardsPerToken);

            // uint256 userRewardsPerTokenPaid = staking.userRewardsPerTokensPaid(ALICE);
            // console2.log("userRewardsPerTokenPaid", userRewardsPerTokenPaid);

            // uint256 lastUpdateTime = staking.lastUpdateTime();
            // console2.log("lastUpdateTime", lastUpdateTime);

            // uint256 applicableTime = staking._lastApplicableTime();
            // console2.log("Last applicable Time", applicableTime);

            // Amount to Unstake
            uint256 amount = 100 ether;

            // Unstake
            staking.Unstake(amount);

            // Get Staker Info
            upgradeableStakingV2.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);

            // Get Alice Balance After unstaking:
            console2.log("Rewardds_Amount", stakerInfo.debtRewards);

            uint256 AliceBalAft = token.balanceOf(address(ALICE));

            console2.log("Alice balance After", AliceBalAft);
            assertEq(AliceBalBef + 100 ether, AliceBalAft);
            assertEq(stakerInfo.amountStaked, 0);
            assertEq(token.balanceOf(address(staking)), 0);
            assertEq(staking.totalStakedTokens(), 0);
        vm.stopPrank();
    }



    function test_revert_Caller_Not_Staker() public {
        test_Stake();
        vm.startPrank(BOB);
            staking.Unstake(100 ether);
            vm.expectRevert(upgradeableStakingV2.ERR_CALLER_NOT_STAKER.selector);
        vm.stopPrank();
    }


    function test_revert_Unstake_Zero_Value() public {
        test_Stake();
        vm.startPrank(ALICE);
            staking.Unstake(0 ether);
            vm.expectRevert(upgradeableStakingV2.ERR_CANNOT_BE_ZERO.selector);
        vm.stopPrank();
    }


    function test_revert_Unstake_Not_Enough_Balance() public {
        test_Stake();
        vm.startPrank(ALICE);
            staking.Unstake(200 ether);
            vm.expectRevert(upgradeableStakingV2.ERR_NOT_ENOUGH_BALANCE.selector);
        vm.stopPrank();
    }



    /********  Claim Unit test *********/
    function test_Claim() external {
        test_Unstake();
        vm.startPrank(ALICE);

            upgradeableStakingV2.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);
            
            // Get Alice's Rewards Debt before claim.
            uint256 aliceRewards = stakerInfo.debtRewards;
            console2.log("Alice's rewards before Claim", aliceRewards);

            uint256 aliceRewardsBalance = staking.balanceOf(ALICE);

            console.log("Alice balance in staking contracts", aliceRewardsBalance);
      
            staking.Claim();

            uint256 aliceRewardsBalanceAft = staking.balanceOf(ALICE);
            
            console.log("Alice balance in staking contracts after Claim", aliceRewardsBalanceAft);

            upgradeableStakingV2.StakerInfo memory stakerInfor = staking.getStakerInfo(ALICE);

            uint256 rewardsAft = stakerInfor.debtRewards;

            console2.log("Alice's rewards after Claim", rewardsAft);
            
            assertEq(rewardsAft, 0);
            assertEq(stakerInfor.lastRewardTimestamp, block.timestamp);
            assertEq(aliceRewardsBalanceAft, 9999999999999952200000000000000000000 ether);
        vm.stopPrank();
    }


    function test_revert_Caller_Not_Claimer() public {
        test_Unstake();
        vm.startPrank(BOB);
            staking.Claim();
            vm.expectRevert(upgradeableStakingV2.ERR_CALLER_NOT_STAKER.selector);
        vm.stopPrank();
    }


    // // Test case when LastApplicabletime is less than lastUpdated time. Check Overflow and Underflow cases. 
    // function test_HandleRewards() public {

    // }




    // function test_setRewards() public {
    //     vm.startPrank(ADMIN);
    //     uint256 rewardsEndTime = staking.rewardsEndTime();
    //     uint256 rewardsRate = staking.rewardRate();
    //     uint256 lastUpdateRate = staking.lastUpdateTime();
    //     uint256 rewardsStarttime = staking.rewardsStartTime();
        
    //     staking.setRewards(REWARD_AMOUNT, REWARD_DURATION);

    //     assertEq(rewardsEndTime, block.timestamp + REWARD_DURATION);
    //     assertEq(rewardsRate, REWARD_AMOUNT /  REWARD_DURATION);
    //     assertEq(lastUpdateRate, block.timestamp);
    //     assertEq(rewardsStarttime, block.timestamp);

    //     vm.stopPrank();

    // }


    

}








