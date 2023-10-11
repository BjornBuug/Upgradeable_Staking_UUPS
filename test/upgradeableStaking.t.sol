// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;


import "forge-std/Test.sol";
import "forge-std/console2.sol";


import "../src/FaucetTokens.sol";
import "../src/UpgradeableStaking.sol";

contract UpgradeableStakingTest is Test {
    using stdStorage for StdStorage;

    // NOTE
    // What could go wrong if the totalsupply of rewards in the contracts is zero(revert)
    // test total pendingrewards is zero
    // test the case when totalPendingReward is less than 0 ?

    // TO BE CONTINUED: 
    // Fixed Staked in case of two stakers
    // NEXT: UNSTAKE AND CLAIM and EGDE CASES.


    // Initial Faucet Supply
    uint256 public constant INITIAL_TOKENS_SUPPLY = 100000000 ether;
    uint256 public constant COOL_DOWN_PERIOD = 60;
    uint256 public constant AMOUNT_TO_WITHDRAW = 10 ether;
    uint256 public constant REWARD_DURATION = 1000000; /// @dev 1000000 seconds = 11.5 days
    uint256 public constant REWARD_AMOUNT = 10000 ether;

    // Rewards rate = _amount / _duration;
    // rewardRate = / 
    // rewards duration == 9999999999999999973800000000000000000000000000000000000000
    // Create an instances of the contracts
    UpgradeableStaking public staking;
    FaucetTokens public token;
    
    address constant public ALICE = address(0x1);
    address constant public BOB = address(0x2);
    address constant public ADMIN = address(0x3);

    // Setting up 
    function setUp() public {
        vm.startPrank(ADMIN);

        staking = new UpgradeableStaking();

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


    /// pending rewards is more than REWARD AMOUNT? Check it out 
    function test_Stake() public {
        
        // Total amount staked for 2 transactions
        uint totalAmountStaked = 200 ether;

        vm.startPrank(ALICE);
            // Amount to Stake
            uint256 amount1 = 100 ether;
            token.approve(address(staking), amount1);

            // Stake
            staking.Stake(amount1);
        vm.stopPrank();


        vm.startPrank(BOB);
            // Amount to Stake
            uint256 amount2 = 100 ether;
            token.approve(address(staking), amount2);

            // Stake
            staking.Stake(amount2);
        vm.stopPrank();

        skip(REWARD_DURATION);

            
            // Alice Info
            UpgradeableStaking.StakerInfo memory aliceInfo = staking.getStakerInfo(ALICE);
            uint256 AlicePendingRewards = staking.getAllPendingRewards(address(ALICE));
            console2.log("ALice Debt Rewards after Rewards duration time passes", AlicePendingRewards);

            // Alice Info
            UpgradeableStaking.StakerInfo memory bobInfo = staking.getStakerInfo(BOB);
            uint256 BobPendingRewards = staking.getAllPendingRewards(address(BOB));
            console2.log("BOB Debt Rewards after Rewards duration time passes", BobPendingRewards);

            
            // ALICE INFO
            assertEq(aliceInfo.staker, ALICE);
            assertEq(aliceInfo.amountStaked, 100 ether);
            assertEq(AlicePendingRewards, REWARD_AMOUNT / 2);

            // BOB INFO
            assertEq(bobInfo.staker, BOB);
            assertEq(bobInfo.amountStaked, 100 ether);
            assertEq(BobPendingRewards, REWARD_AMOUNT / 2);

            assertEq(token.balanceOf(address(staking)), totalAmountStaked);
            assertEq(staking.totalStakedTokens(), totalAmountStaked);
            
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
            vm.expectRevert(UpgradeableStaking.ERR_AMOUNT_BELOW_MIN.selector);
        vm.stopPrank();
    }


    function test_revert_Stake_Zero_Address() public {
        vm.startPrank(address(0));
            // Test below Minimum 
            uint256 amount = 10 ether;
            staking.Stake(amount);
            vm.expectRevert(UpgradeableStaking.ERR_ADDRESS_CANNOT_BE_ZERO.selector);
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

            // Amount to Unstake
            uint256 amount = 100 ether;

            // Unstake
            staking.Unstake(amount);

            // Get Staker Info
            UpgradeableStaking.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);

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
            vm.expectRevert(UpgradeableStaking.ERR_CALLER_NOT_STAKER.selector);
        vm.stopPrank();
    }


    function test_revert_Unstake_Zero_Value() public {
        test_Stake();
        vm.startPrank(ALICE);
            staking.Unstake(0 ether);
            vm.expectRevert(UpgradeableStaking.ERR_CANNOT_BE_ZERO.selector);
        vm.stopPrank();
    }


    function test_revert_Unstake_Not_Enough_Balance() public {
        test_Stake();
        vm.startPrank(ALICE);
            staking.Unstake(200 ether);
            vm.expectRevert(UpgradeableStaking.ERR_NOT_ENOUGH_BALANCE.selector);
        vm.stopPrank();
    }



    /********  Claim Unit test *********/
    function test_Claim() public {
        test_Unstake();
        vm.startPrank(ALICE);

            UpgradeableStaking.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);
            
            // Get Alice's Rewards Debt before claim.
            uint256 aliceRewards = stakerInfo.debtRewards;

            console2.log("Alice's rewards before Claim", aliceRewards);

            uint256 aliceRewardsBalance = staking.balanceOf(ALICE);

            console.log("Alice balance in staking contracts", aliceRewardsBalance);
      
            staking.Claim();

            uint256 aliceRewardsBalanceAft = staking.balanceOf(ALICE);
            
            console.log("Alice balance in staking contracts after Claim", aliceRewardsBalanceAft);

            UpgradeableStaking.StakerInfo memory stakerInfor = staking.getStakerInfo(ALICE);

            uint256 rewardsAft = stakerInfor.debtRewards;

            console2.log("Alice's rewards after Claim", rewardsAft);
            
            assertEq(rewardsAft, 0);
            assertEq(stakerInfor.lastRewardTimestamp, block.timestamp);
            // assertEq(aliceRewardsBalanceAft, 9999999999999952200000000000000000000 ether);
        vm.stopPrank();
    }


    function test_revert_Caller_Not_Claimer() public {
        test_Unstake();
        vm.startPrank(BOB);
            staking.Claim();
            vm.expectRevert(UpgradeableStaking.ERR_CALLER_NOT_STAKER.selector);
        vm.stopPrank();
    }


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








