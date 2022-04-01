// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {

    address public antiparallelTokenAddress;

    // Exchange inheriting ERC20 in order to keep track of LP tokens
    constructor(address _AntiparallelToken) ERC20("Antiparallel LP Token", "APLP") {
        require(_AntiparallelToken != address(0), "Token address passed is a null address");
        antiparallelTokenAddress = _AntiparallelToken;
    }

    /**
    *  @dev Returns amount of Antiparallel tokens held by the contract
    */
    function getReserve() public view returns (uint) {
        return ERC20(antiparallelTokenAddress).balanceOf(address(this));
    }

    /**
    * @dev Adds liquidity to the exchange
    */
    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint antiparallelTokenReserve = getReserve();
        ERC20 antiparallelToken = ERC20(antiparallelTokenAddress);
        /*
            If the reserve is empty, intake any user supplied value for
            `Ether` and `Antiparallel` tokens because there is no ratio currently
        */
        if(antiparallelTokenReserve == 0) {
            // Transfer the `antiparallelToken` from the user's account to the contract
            antiparallelToken.transferFrom(msg.sender, address(this), _amount);
            // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
            // `liquidity` provided is equal to `ethBalance` because first time user is adding
            // `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied
            // by the user in the current `addLiquidity` call.
            // `liquidity` tokens that need to be minted to the user on `addLiquidity` call should always be propotional
            // to the eth specified by the user
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
            // _mint is ERC20.sol smart contract function to mint ERC20 tokens
        } else {
            /*
                If the reserve is not empty, intake any user supplied value for
                `Ether` and determine according to the ratio how many Antiparallel tokens
                need to be supplied to prevent any large price impacts from the additional
                liquidity
            */
            // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user
            // in the current `addLiquidity` call
            uint ethReserve =  ethBalance - msg.value;
            // Ratio should always be maintained so that there are no major price impacts when adding liquidity
            // Ratio here is -> (antiparallelTokenAmount user can add/antiparallelTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
            // So doing some maths, (antiparallelTokenAmount user can add) = (Eth Sent by the user * antiparallelTokenReserve /Eth Reserve);
            uint antiparallelTokenAmount = (msg.value * antiparallelTokenReserve)/(ethReserve);
            require(_amount >= antiparallelTokenAmount, "Amount of tokens sent is less than the minimum tokens required");
            // transfer only (antiparallelTokenAmount user can add) amount of Antiparallel tokens from users account
            // to the contract
            antiparallelToken.transferFrom(msg.sender, address(this), antiparallelTokenAmount);
            // The amount of LP tokens that would be sent to the user should be propotional to the liquidity of
            // ether added by the user
            // Ratio here to be maintained is ->
            // (LP tokens to be sent to the user(liquidity)/ totalSupply of LP tokens in contract) = (eth sent by the user)/(eth reserve in the contract)
            // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (eth sent by the user))/(eth reserve in the contract)
            liquidity = (totalSupply() * msg.value)/ ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }
}