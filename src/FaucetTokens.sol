// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;



import "openzeppelin/token/ERC20/ERC20.sol";



contract FaucetTokens {
        error TooManyRequest;

        // Keep track of each users withdrawls
        mapping (address => uint256) public withdrawlsTrackers;
        uint256 public coolDownPeriod;
        uint256 public amountPerRequest;

        constructor(
            uint256 _initialSupply,
            uint256 _coolDownPeriod,
            uint256 _withdrawPerRequest
        )ERC20("Faucet Tokens","FCT") {
            coolDownPeriod = _coolDownPeriod;
            amountPerRequest = _amountPerRequest;
            _mint(msg.sender, InitialSupply);
        }


        ///@dev function allow user to request tokens each 24H 
        function faucet() external {

            // Verify is user tries to request more than one request withing the one cooldown period
            if(withdrawlsTrackers[msg.sender] > block.timestamp) {
                revert TooManyRequest();
            }

            withdrawlsTrackers[msg.sender] = block.timestamp + coolDownPeriod;
            _mint(msg.sender, amountPerRequest);
        }
}