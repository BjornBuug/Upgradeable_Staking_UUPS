// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;


import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/upgradeableStaking.sol";
import "../src/FaucetTokens.sol";

contract UpgradeableStakingTest is Test {


    // Initial Faucet Supply
    uint256 public constant INITIAL_TOKENS_SUPPLY = 1000 ether;
    uint256 public constant COOL_DOWN_PERIOD = 60;
    uint256 public constant AMOUNT_TO_WITHDRAW = 10 ether;


    // Create an instances of the contracts
    UpgradeableStaking public staking;
    FaucetTokens public token;


    // Setting up 
    function setup() public {
        staking = new UpgradeableStaking();

        // Initialize the token faucet
        token = new FaucetTokens(
            INITIAL_TOKENS_SUPPLY,
            COOL_DOWN_PERIOD,
            AMOUNT_TO_WITHDRAW
        );

        staking.initilize(IERC20Upgradeable(address(token)));
    }

}








