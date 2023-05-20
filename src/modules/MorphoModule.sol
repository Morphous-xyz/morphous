// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import {IMorpho} from "src/interfaces/IMorpho.sol";
import {ICToken} from "src/interfaces/ICToken.sol";
import {Constants} from "src/libraries/Constants.sol";
import {TokenUtils} from "src/libraries/TokenUtils.sol";
import {IPoolToken} from "src/interfaces/IPoolToken.sol";
import {ERC20, SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IRewardsDistributor} from "src/interfaces/IRewardsDistributor.sol";

contract MorphoModule {
    using SafeTransferLib for ERC20;

    /// @notice Rewards Distributor to claim $MORPHO token.
    address internal constant _REWARDS_DISTRIBUTOR = 0x3B14E5C73e0A56D607A8688098326fD4b4292135;

    event Borrowed(address indexed token, uint256 amount);
    event BorrowedWithMaxGas(address indexed token, uint256 amount, uint256 maxGas);
    event Repaid(address indexed token, address onBehalf, uint256 amount);

    event RewardClaimed(uint256 _claimable);
    event MorphoClaimed(address _account, uint256 _claimable);

    event SuppliedOnBehalf(address indexed token, uint256 amount, address indexed onBehalfOf);
    event SuppliedWithMaxGas(address indexed token, uint256 amount, address indexed onBehalOf, uint256 maxGas);
    event Withdrawn(address indexed token, uint256 amount);

    ////////////////////////////////////////////////////////////////
    /// --- Core
    ///////////////////////////////////////////////////////////////

    modifier onlyValidMarket(address _market) {
        if (_market != Constants._MORPHO_AAVE && _market != Constants._MORPHO_COMPOUND) {
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

    function borrow(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount);

        emit Borrowed(_token, _amount);
    }

    function borrow(address _market, address _poolToken, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);
        IMorpho(_market).borrow(_poolToken, _amount, _maxGasForMatching);

        emit BorrowedWithMaxGas(_token, _amount, _maxGasForMatching);
    }

    function repay(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).repay(_poolToken, _onBehalf, _amount);

        emit Repaid(_token, _onBehalf, _amount);
    }

    ////////////////////////////////////////////////////////////////
    /// --- Claim rewards
    ///////////////////////////////////////////////////////////////

    function claim(address _account, uint256 _claimable, bytes32[] calldata _proof) external {
        IRewardsDistributor(_REWARDS_DISTRIBUTOR).claim(_account, _claimable, _proof);

        emit MorphoClaimed(_account, _claimable);
    }

    function claim(address _market, address[] calldata _poolTokens, bool _tradeForMorphoToken)
        external
        onlyValidMarket(_market)
    {
        uint256 _claimed = IMorpho(_market).claimRewards(_poolTokens, _tradeForMorphoToken);

        emit RewardClaimed(_claimed);
    }

    ////////////////////////////////////////////////////////////////
    /// --- Supply / Withdraw
    ///////////////////////////////////////////////////////////////

    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).supply(_poolToken, _onBehalf, _amount);

        emit SuppliedOnBehalf(_poolToken, _amount, _onBehalf);
    }

    function supply(address _market, address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching)
        external
        onlyValidMarket(_market)
    {
        address _token = _getToken(_market, _poolToken);

        TokenUtils._approve(_token, _market, _amount);
        IMorpho(_market).supply(_poolToken, _onBehalf, _amount, _maxGasForMatching);

        emit SuppliedWithMaxGas(_poolToken, _amount, _onBehalf, _maxGasForMatching);
    }

    function withdraw(address _market, address _poolToken, uint256 _amount) external onlyValidMarket(_market) {
        IMorpho(_market).withdraw(_poolToken, _amount);

        emit Withdrawn(_poolToken, _amount);
    }
}
