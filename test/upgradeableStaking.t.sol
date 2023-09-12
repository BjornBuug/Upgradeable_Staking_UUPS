// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;


import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "../src/UpgradeableStaking.sol";
import "../src/FaucetTokens.sol";

contract UpgradeableStakingTest is Test {
    using stdStorage for StdStorage;

    // Stake [x]
    // Unstake []
    // 

    // Initial Faucet Supply
    uint256 public constant INITIAL_TOKENS_SUPPLY = 100000000 ether;
    uint256 public constant COOL_DOWN_PERIOD = 60;
    uint256 public constant AMOUNT_TO_WITHDRAW = 10 ether;
    uint256 public constant REWARD_DURATION = 1000000; /// @dev 1000000 seconds = 11.5 days


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
        staking.setRewards(AMOUNT_TO_WITHDRAW, COOL_DOWN_PERIOD);
        vm.stopPrank();
    }


    function test_Stake() public {
        vm.startPrank(ALICE);
            // Amount to Stake
            uint256 amount = 100 ether;
            token.approve(address(staking), amount);
            // Stake
            staking.Stake(amount);
            // Get Staker Info
            UpgradeableStaking.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);
            assertEq(stakerInfo.staker, ALICE);
            assertEq(stakerInfo.amountStaked, amount);
            assertEq(token.balanceOf(address(staking)), amount);
            assertEq(staking.totalStakedTokens(), amount);
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

            // Amount to Stake
            uint256 amount = 100 ether;
            // Unstake
            staking.Unstake(amount);

            // Get Staker Info
            UpgradeableStaking.StakerInfo memory stakerInfo = staking.getStakerInfo(ALICE);

            // Get Alice Balance After unstaking:
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
    // STOPED HERE
    function test_Claim() external {
        test_Stake();
        test_Unstake();
        vm.startPrank(ALICE);
        uint256 claimedAmount = 100 ether;
        skip(REWARD_DURATION);
            staking.Claim(claimedAmount);
        StakerInfo storage stakerInfo = stakers[msg.sender];
        vm.stopPrank();
    }


    

}








