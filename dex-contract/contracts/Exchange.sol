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

    /**
    * @dev Removes liquidity from the exchange
    */
    function removeLiquidity(uint _amount) public returns (uint , uint) {
        require(_amount > 0, "_amount should be greater than zero");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();
        // The amount of Eth to be sent back to the user is based
        // on a ratio
        // Ratio is -> (Eth sent back to the user/ Current Eth reserve)
        // = (amount of LP tokens that user wants to withdraw)/ Total supply of `LP` tokens)
        // Then by some maths -> (Eth sent back to the user)
        // = (Current Eth reserve * amount of LP tokens that user wants to withdraw)/Total supply of `LP` tokens
        uint ethAmount = (ethReserve * _amount)/ _totalSupply;
        // The amount of Antiparallel tokens that would be sent back to the user is based
        // on a ratio
        // Ratio is -> (Antiparallel token sent back to the user/ Current Antiparallel token reserve)
        // = (amount of LP tokens that user wants to withdraw)/ Total supply of `LP` tokens)
        // Then by some maths -> (Antiparallel tokens sent back to the user)
        // = (Current Antiparallel token reserve * amount of LP tokens that user wants to withdraw)/Total supply of `LP` tokens
        uint antiparallelTokenAmount = (getReserve() * _amount)/ _totalSupply;
        // Burn the sent `LP` tokens from the user'a wallet because they are already sent to
        // remove liquidity
        _burn(msg.sender, _amount);
        // Transfer `ethAmount` of Eth from user's wallet to the contract
        payable(msg.sender).transfer(ethAmount);
        // Transfer `antiparallelTokenAmount` of Antiparallel tokens from the user's wallet to the contract
        ERC20(antiparallelTokenAddress).transfer(msg.sender, antiparallelTokenAmount);
        return (ethAmount, antiparallelTokenAmount);
    }

    /**
    @dev Returns the amount of Eth/Antiparallel tokens to be returned to the user
    * in the swap
    */
    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        // Charging fee of 1%
        // Input amount with fees = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
        uint256 inputAmountWithFee = inputAmount * 99;
        // Need to follow the concept of `XY = K` curve
        // Need to make sure (x + Δx)*(y - Δy) = (x)*(y)
        // so the final formula is Δy = (y*Δx)/(x + Δx);
        // Δy in this case is `tokens to be recieved`
        // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

        /**
     @dev Swaps Ether for Antiparallel Tokens
    */
    function ethToAntiparallelToken(uint _minTokens) public payable {
    uint256 tokenReserve = getReserve();
    // call the `getAmountOfTokens` to get the amount of Antiparallel tokens
    // to be returned to the user after the swap
    // The `inputReserve` we are sending is equal to
    //  `address(this).balance - msg.value` instead of just `address(this).balance`
    // because `address(this).balance` already contains the `msg.value` user has sent in the given call
    // so we need to subtract it to get the actual input reserve
    uint256 tokensBought = getAmountOfTokens(
        msg.value,
        address(this).balance - msg.value,
        tokenReserve
    );

    require(tokensBought >= _minTokens, "insufficient output amount");
    // Transfer the Antiparallel tokens to the user
    ERC20(antiparallelTokenAddress).transfer(msg.sender, tokensBought);
    }

    /**
    @dev Swaps Antiparallel Tokens for Ether
    */
    function antiparallelTokenToEth(uint _tokensSold, uint _minEth) public {
    uint256 tokenReserve = getReserve();
        // call the `getAmountOfTokens` to get the amount of ether
        // to be returned to the user after the swap
        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );
        require(ethBought >= _minEth, "insufficient output amount");
        // Transfer Antiparallel tokens from the user's address to the contract
        ERC20(antiparallelTokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        // send the `ethBought` to the user from the contract
        payable(msg.sender).transfer(ethBought);
    }
}