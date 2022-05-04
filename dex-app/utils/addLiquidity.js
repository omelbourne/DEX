import { Contract, utils } from "ethers";
import {
  EXCHANGE_CONTRACT_ABI,
  EXCHANGE_CONTRACT_ADDRESS,
  TOKEN_CONTRACT_ABI,
  TOKEN_CONTRACT_ADDRESS,
} from "../constants";

/**
 * addLiquidity helps add liquidity to the exchange,
 * If the user is adding initial liquidity, user decides the ether and tokens to add
 * to the exchange. If adding after the initial liquidity then we calculate the
 * tokens that can be added, given the eth desired to be added, by keeping the ratios
 * constant
 */
export const addLiquidity = async (
  signer,
  addAntiparallelAmountWei,
  addEtherAmountWei
) => {
  try {
    // create a new instance of the token contract
    const tokenContract = new Contract(
      TOKEN_CONTRACT_ADDRESS,
      TOKEN_CONTRACT_ABI,
      signer
    );
    // create a new instance of the exchange contract
    const exchangeContract = new Contract(
      EXCHANGE_CONTRACT_ADDRESS,
      EXCHANGE_CONTRACT_ABI,
      signer
    );
    // Because tokens are an ERC20, user would need to give the contract approval
    // to take the required number of tokens out of contract
    let tx = await tokenContract.approve(
      EXCHANGE_CONTRACT_ADDRESS,
      addAntiparallelAmountWei.toString()
    );
    await tx.wait();
    // After the contract has the approval, add the ether and tokens liquidity
    tx = await exchangeContract.addLiquidity(addAntiparallelAmountWei, {
      value: addEtherAmountWei,
    });
    await tx.wait();
  } catch (err) {
    console.error(err);
  }
};

/**
 * calculateAntiparallel calculates the Antiparallel tokens that need to be added to the liquidity
 * given `_addEtherAmountWei` amount of ether
 */
export const calculateAntiparallel = async (
  _addEther = "0",
  etherBalanceContract,
  antiparallelTokenReserve
) => {
  // `_addEther` is a string, we need to convert it to a Bignumber before we can do our calculations
  // We do that using the `parseEther` function from `ethers.js`
  const _addEtherAmountWei = utils.parseEther(_addEther);
  // Ratio needs to be maintained when we add liquiidty.
  // We need to let the user know (who has a specific amount of ether) how many tokens
  // they can add so that the price impact is not large
  // The ratio we follow is (Amount of tokens to be added)/(tokens balance) = (Ether that would be added)/ (Eth reseve in the contract)
  // So by maths we get (Amount of tokens to be added) = (Ether that would be added * tokens balance)/ (Eth reseve in the contract)
  const antiparallelTokenAmount = _addEtherAmountWei
    .mul(antiparallelTokenReserve)
    .div(etherBalanceContract);
  return antiparallelTokenAmount;
};