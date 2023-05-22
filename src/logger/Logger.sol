// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

contract Logger {
    event SuppliedOnBehalf(address indexed token, uint256 amount, address indexed onBehalfOf);
    event SuppliedWithMaxGas(address indexed token, uint256 amount, address indexed onBehalfOf, uint256 maxGas);

    event Withdrawn(address indexed token, uint256 amount);

    event RewardClaimed(uint256 _claimable);
    event MorphoClaimed(address _account, uint256 _claimable);

    event Borrowed(address indexed token, uint256 amount);
    event BorrowedWithMaxGas(address indexed token, uint256 amount, uint256 maxGas);
    event Repaid(address indexed token, address onBehalf, uint256 amount);

    event ExchangeAggregator(address _tokenFrom, address _tokenTo, uint256 _amountFrom, uint256 _amountTo);

    function logSupply(address _poolToken, address _onBehalf, uint256 _amount) external {
        emit SuppliedOnBehalf(_poolToken, _amount, _onBehalf);
    }

    function logSupply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching) external {
        emit SuppliedWithMaxGas(_poolToken, _amount, _onBehalf, _maxGasForMatching);
    }

    function logWithdraw(address _poolToken, uint256 _amount) external {
        emit Withdrawn(_poolToken, _amount);
    }

    function logRewardClaimed(uint256 _claimable) external {
        emit RewardClaimed(_claimable);
    }

    function logMorphoClaimed(address _account, uint256 _claimable) external {
        emit MorphoClaimed(_account, _claimable);
    }

    function logBorrow(address _poolToken, uint256 _amount) external {
        emit Borrowed(_poolToken, _amount);
    }

    function logBorrow(address _poolToken, uint256 _amount, uint256 _maxGasForMatching) external {
        emit BorrowedWithMaxGas(_poolToken, _amount, _maxGasForMatching);
    }

    function logRepay(address _poolToken, address _onBehalf, uint256 _amount) external {
        emit Repaid(_poolToken, _onBehalf, _amount);
    }

    function logExchangeAggregator(address _tokenFrom, address _tokenTo, uint256 _amountFrom, uint256 _amountTo)
        external
    {
        emit ExchangeAggregator(_tokenFrom, _tokenTo, _amountFrom, _amountTo);
    }
}
