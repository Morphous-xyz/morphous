// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {BaseModule} from "src/modules/BaseModule.sol";
import {Logger} from "src/logger/Logger.sol";
import {IMorpho} from "src/interfaces/IMorpho.sol";
import {ICToken} from "src/interfaces/ICToken.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IRewardsDistributor} from "src/interfaces/IRewardsDistributor.sol";

contract MorphoModule is BaseModule {
    using SafeTransferLib for ERC20;

    /// @notice Rewards Distributor to claim $MORPHO token.
    address internal constant _REWARDS_DISTRIBUTOR = 0x3B14E5C73e0A56D607A8688098326fD4b4292135;

    constructor(Logger logger) BaseModule(logger) {}

    ////////////////////////////////////////////////////////////////
    /// --- Core
    ///////////////////////////////////////////////////////////////

    modifier onlyValidMarket(address _market) {
        if (
            _market != Constants._MORPHO_AAVE && _market != Constants._MORPHO_COMPOUND
                && _market != Constants._MORPHO_AAVE_V3
        ) {
            revert Constants.INVALID_MARKET();
        }
        _;
    }

    function _getToken(address _market, address _poolToken) internal view returns (address) {
        if (_market == Constants._MORPHO_AAVE) return IPoolToken(_poolToken).UNDERLYING_ASSET_ADDRESS();
        else if (_market == Constants._MORPHO_COMPOUND && _poolToken == Constants._cETHER) return Constants._WETH;
        else if (_market == Constants._MORPHO_COMPOUND) return ICToken(_poolToken).underlying();
        else revert Constants.INVALID_MARKET();
    }

    ////////////////////////////////////////////////////////////////
    /// --- Borrow / Repay
    ///////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////
    /// --- V2
    ///////////////////////////////////////////////////////////////

    function borrow(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount);

        LOGGER.logBorrow(_token, _amount);
    }

    function borrow(address _market, address _poolToken, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount, _maxGasForMatching);

        LOGGER.logBorrow(_token, _amount, _maxGasForMatching);
    }

    function repay(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).repay(_poolToken, _onBehalf, _amount);

        LOGGER.logRepay(_token, _onBehalf, _amount);
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////

    /// TODO: Update all EVENTS for V3

    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
    {
        IMorpho(Constants._MORPHO_AAVE_V3).borrow(underlying, amount, onBehalf, receiver, maxIterations);

        LOGGER.logBorrow(underlying, amount);
    }

    function repay(address underlying, uint256 amount, address onBehalf) external {
        TokenUtils._approve(underlying, Constants._MORPHO_AAVE_V3, amount);
        IMorpho(Constants._MORPHO_AAVE_V3).repay(underlying, onBehalf, amount);

        LOGGER.logRepay(underlying, onBehalf, amount);
    }

    ////////////////////////////////////////////////////////////////
    /// --- Claim rewards
    ///////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////
    /// --- V2
    ///////////////////////////////////////////////////////////////

    function claim(address _account, uint256 _claimable, bytes32[] calldata _proof) external {
        IRewardsDistributor(_REWARDS_DISTRIBUTOR).claim(_account, _claimable, _proof);

        LOGGER.logMorphoClaimed(_account, _claimable);
    }

    function claim(address _market, address[] calldata _poolTokens, bool _tradeForMorphoToken)
        external
        onlyValidMarket(_market)
    {
        uint256 _claimed = IMorpho(_market).claimRewards(_poolTokens, _tradeForMorphoToken);

        LOGGER.logRewardClaimed(_claimed);
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////

    /// TODO: Update all EVENTS for V3

    function claim(address[] calldata assets, address onBehalf) external {
        IMorpho(Constants._MORPHO_AAVE_V3).claimRewards(assets, onBehalf);
    }

    ////////////////////////////////////////////////////////////////
    /// --- Supply / Withdraw
    ///////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////
    /// --- V2
    ///////////////////////////////////////////////////////////////

    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);

        IMorpho(_market).supply(_poolToken, _onBehalf, _amount);

        LOGGER.logSupply(_poolToken, _onBehalf, _amount);
    }

    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);

        LOGGER.logSupply(_poolToken, _onBehalf, _amount, _maxGasForMatching);
    }

    function withdraw(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        IMorpho(_market).withdraw(_poolToken, _amount);

        LOGGER.logWithdraw(_poolToken, _amount);
    }

    ////////////////////////////////////////////////////////////////
    /// --- V3
    ///////////////////////////////////////////////////////////////

    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations) external {
        TokenUtils._approve(underlying, Constants._MORPHO_AAVE_V3, amount);
        IMorpho(Constants._MORPHO_AAVE_V3).supply(underlying, amount, onBehalf, maxIterations);

        LOGGER.logSupply(underlying, address(this), amount);
    }

    function supplyCollateral(address underlying, uint256 amount, address onBehalf) external {
        TokenUtils._approve(underlying, Constants._MORPHO_AAVE_V3, amount);
        IMorpho(Constants._MORPHO_AAVE_V3).supplyCollateral(underlying, amount, onBehalf);

        LOGGER.logSupply(underlying, address(this), amount);
    }

    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
    {
        IMorpho(Constants._MORPHO_AAVE_V3).withdraw(underlying, amount, onBehalf, receiver, maxIterations);
        LOGGER.logWithdraw(underlying, amount);
    }

    function withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver) external {
        IMorpho(Constants._MORPHO_AAVE_V3).withdrawCollateral(underlying, amount, onBehalf, receiver);
        LOGGER.logWithdraw(underlying, amount);
    }
}
