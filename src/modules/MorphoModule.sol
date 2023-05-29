// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.20;

import {Logger} from "src/Logger.sol";
import {ICToken} from "src/interfaces/ICToken.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";
import {BaseModule} from "src/modules/BaseModule.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IRewardsDistributor} from "src/interfaces/IRewardsDistributor.sol";

/// @title MorphoModule
/// @notice A module for managing borrowing, repayments, claims, and supply/withdraw operations for different market versions (v2 and v3).
contract MorphoModule is BaseModule {
    using SafeTransferLib for ERC20;

    /// @notice Rewards Distributor to claim $MORPHO token.
    address internal constant _REWARDS_DISTRIBUTOR = 0x3B14E5C73e0A56D607A8688098326fD4b4292135;

    constructor(Logger logger) BaseModule(logger) {}

    ////////////////////////////////////////////////////////////////
    /// --- CORE
    ///////////////////////////////////////////////////////////////

    /// @notice Checks if the market address provided is a valid one.
    /// @param _market The address of the market to be checked.
    modifier onlyValidMarket(address _market) {
        if (
            _market != Constants._MORPHO_AAVE && _market != Constants._MORPHO_COMPOUND
                && _market != Constants._MORPHO_AAVE_V3
        ) {
            revert Constants.INVALID_MARKET();
        }
        _;
    }

    /// @notice Retrieves the token address for a given market and pool token.
    /// @param _market The address of the market.
    /// @param _poolToken The address of the pool token.
    /// @return The address of the token.
    function _getToken(address _market, address _poolToken) internal view returns (address) {
        if (_market == Constants._MORPHO_AAVE) return IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS();
        else if (_market == Constants._MORPHO_COMPOUND && _poolToken == Constants._cETHER) return Constants._WETH;
        else if (_market == Constants._MORPHO_COMPOUND) return ICToken(_poolToken).underlying();
        else revert Constants.INVALID_MARKET();
    }

    ////////////////////////////////////////////////////////////////
    /// --- BORROW / REPAY
    /// --- COMPOUND/V2
    ///////////////////////////////////////////////////////////////

    /// @notice Borrow a specified amount from the specified market.
    /// @param _market The market to borrow from.
    /// @param _poolToken The token to borrow.
    /// @param _amount The amount to borrow.
    function borrow(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount);

        LOGGER.log("Borrow_V2", abi.encode(_token, _amount));
    }

    /// @notice Borrow a specified amount from the specified market using a gas limit.
    /// @param _market The market to borrow from.
    /// @param _poolToken The token to borrow.
    /// @param _amount The amount to borrow.
    /// @param _maxGasForMatching The gas limit for the borrow matching operation.
    function borrow(address _market, address _poolToken, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount, _maxGasForMatching);

        LOGGER.log("BorrowWithGasMatch_V2", abi.encode(_token, _amount, _maxGasForMatching));
    }

    /// @notice Repay a specified amount on behalf of an address in the specified market.
    /// @param _market The market to repay to.
    /// @param _poolToken The token to repay.
    /// @param _onBehalf The address to repay on behalf of.
    /// @param _amount The amount to repay.
    function repay(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).repay(_poolToken, _onBehalf, _amount);

        LOGGER.log("Repay_V2", abi.encode(_token, _onBehalf, _amount));
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////

    /// @notice Borrow a specified amount from Aave V3 market on behalf of an address, sending it to a specified receiver with a specified number of iterations.
    /// @param underlying The underlying token to borrow.
    /// @param amount The amount to borrow.
    /// @param onBehalf The address on whose behalf to borrow.
    /// @param receiver The address to send the borrowed tokens to.
    /// @param maxIterations The number of iterations for the borrow operation.
    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
    {
        IMorpho(Constants._MORPHO_AAVE_V3).borrow(underlying, amount, onBehalf, receiver, maxIterations);

        LOGGER.log("Borrow_V3", abi.encode(underlying, amount, onBehalf, receiver, maxIterations));
    }

    /// @notice Repay a specified amount on behalf of an address to the Aave V3 market.
    /// @param underlying The underlying token to repay.
    /// @param amount The amount to repay.
    /// @param onBehalf The address on whose behalf to repay.
    function repay(address underlying, uint256 amount, address onBehalf) external returns (uint256) {
        TokenUtils._approve(underlying, Constants._MORPHO_AAVE_V3, amount);
        LOGGER.log("Repay_V3", abi.encode(underlying, amount, onBehalf));

        return IMorpho(Constants._MORPHO_AAVE_V3).repay(underlying, amount, onBehalf);
    }

    ////////////////////////////////////////////////////////////////
    /// --- CLAIM REWARDS
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards for a specified account.
    /// @param _account The account to claim rewards for.
    /// @param _claimable The claimable amount.
    /// @param _proof The proof to validate the claim.
    function claim(address _account, uint256 _claimable, bytes32[] calldata _proof) external {
        IRewardsDistributor(_REWARDS_DISTRIBUTOR).claim(_account, _claimable, _proof);

        LOGGER.log("MorphoClaim", abi.encode(_account, _claimable));
    }

    ////////////////////////////////////////////////////////////////
    /// --- COMPOUND/V2
    ///////////////////////////////////////////////////////////////

    /// @notice Claim rewards on the specified market.
    /// @param _market The market to claim rewards from.
    /// @param _poolTokens The tokens to claim rewards from.
    /// @param _tradeForMorphoToken If true, trades rewards for Morpho token.
    function claim(address _market, address[] calldata _poolTokens, bool _tradeForMorphoToken)
        external
        onlyValidMarket(_market)
    {
        uint256 _claimed = IMorpho(_market).claimRewards(_poolTokens, _tradeForMorphoToken);

        LOGGER.log("Claim_V2", abi.encode(_claimed));
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////

    /// @notice Claims rewards for the specified assets on behalf of an address.
    /// @param assets The assets to claim rewards for.
    /// @param onBehalf The address to claim rewards on behalf of.
    function claim(address[] calldata assets, address onBehalf) external {
        (address[] memory claimedAssets, uint256[] memory claimed) =
            IMorpho(Constants._MORPHO_AAVE_V3).claimRewards(assets, onBehalf);
        LOGGER.log("Claim_V3", abi.encode(claimedAssets, claimed));
    }

    ////////////////////////////////////////////////////////////////
    /// --- SUPPLY / WITHDRAW
    /// --- COMPOUND/V2
    ///////////////////////////////////////////////////////////////

    /// @notice Supply a specified amount to the specified market on behalf of an address.
    /// @param _market The market to supply to.
    /// @param _poolToken The token to supply.
    /// @param _onBehalf The address to supply on behalf of.
    /// @param _amount The amount to supply.
    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);

        IMorpho(_market).supply(_poolToken, _onBehalf, _amount);

        LOGGER.log("Supply_V2", abi.encode(_poolToken, _onBehalf, _amount));
    }

    /// @notice Supply a specified amount to the specified market using a gas limit on behalf of an address.
    /// @param _market The market to supply to.
    /// @param _poolToken The token to supply.
    /// @param _onBehalf The address to supply on behalf of.
    /// @param _amount The amount to supply.
    /// @param _maxGasForMatching The gas limit for the supply operation.
    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);

        LOGGER.log("SupplyWithGasMatch_V2", abi.encode(_poolToken, _onBehalf, _amount, _maxGasForMatching));
    }

    /// @notice Withdraw a specified amount from the specified market.
    /// @param _market The market to withdraw from.
    /// @param _poolToken The token to withdraw.
    /// @param _amount The amount to withdraw.
    function withdraw(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        IMorpho(_market).withdraw(_poolToken, _amount);

        LOGGER.log("Withdraw_V2", abi.encode(_poolToken, _amount));
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////

    /// @notice Supply a specified amount to the Aave V3 market on behalf of an address with a specified number of iterations.
    /// @param underlying The underlying token to supply.
    /// @param amount The amount to supply.
    /// @param onBehalf The address to supply on behalf of.
    /// @param maxIterations The number of iterations for the supply operation.
    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations) external {
        TokenUtils._approve(underlying, Constants._MORPHO_AAVE_V3, amount);
        IMorpho(Constants._MORPHO_AAVE_V3).supply(underlying, amount, onBehalf, maxIterations);

        LOGGER.log("Supply_V3", abi.encode(underlying, address(this), amount, maxIterations));
    }

    /// @notice Supply a specified amount to the Aave V3 market as collateral on behalf of an address.
    /// @param underlying The underlying token to supply.
    /// @param amount The amount to supply.
    /// @param onBehalf The address to supply on behalf of.
    function supplyCollateral(address underlying, uint256 amount, address onBehalf) external {
        TokenUtils._approve(underlying, Constants._MORPHO_AAVE_V3, amount);
        IMorpho(Constants._MORPHO_AAVE_V3).supplyCollateral(underlying, amount, onBehalf);

        LOGGER.log("SupplyCollateral_V3", abi.encode(underlying, address(this), amount));
    }

    /// @notice Withdraw a specified amount from the Aave V3 market on behalf of an address, sending it to a specified receiver with a specified number of iterations.
    /// @param underlying The underlying token to withdraw.
    /// @param amount The amount to withdraw.
    /// @param onBehalf The address to withdraw on behalf of.
    /// @param receiver The address to send the withdrawn tokens to.
    /// @param maxIterations The number of iterations for the withdraw operation.
    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256)
    {
        LOGGER.log("Withdraw_V3", abi.encode(underlying, amount, maxIterations));
        return IMorpho(Constants._MORPHO_AAVE_V3).withdraw(underlying, amount, onBehalf, receiver, maxIterations);
    }

    /// @notice Withdraw a specified amount from the Aave V3 market as collateral on behalf of an address, sending it to a specified receiver.
    /// @param underlying The underlying token to withdraw.
    /// @param amount The amount to withdraw.
    /// @param onBehalf The address to withdraw on behalf of.
    /// @param receiver The address to send the withdrawn tokens to.
    function withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver)
        external
        returns (uint256)
    {
        LOGGER.log("WithdrawCollateral_V3", abi.encode(underlying, amount, onBehalf, receiver));
        return IMorpho(Constants._MORPHO_AAVE_V3).withdrawCollateral(underlying, amount, onBehalf, receiver);
    }
}
