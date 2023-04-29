// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IMorpho {
    function supply(address _poolToken, uint256 _amount) external;
    function supply(address _poolToken, address _onBehalf, uint256 _amount) external;
    function supply(address _poolToken, address _onBehalf, uint256 _amount, uint256 _maxGasForMatching) external;
    function supply(address underlying, uint256 amount, address onBehalf, uint256 maxIterations)
        external
        returns (uint256);
    function supplyCollateral(address underlying, uint256 amount, address onBehalf) external returns (uint256);

    function withdraw(address _poolToken, uint256 _amount) external;
    function withdraw(address _poolToken, uint256 _amount, address _receiver) external;

    function withdraw(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256);
    function withdrawCollateral(address underlying, uint256 amount, address onBehalf, address receiver)
        external
        returns (uint256);

    function borrow(address _poolToken, uint256 _amount) external;
    function borrow(address _poolToken, uint256 _maxGasForMatching, uint256 _amount) external;
    function borrow(address underlying, uint256 amount, address onBehalf, address receiver, uint256 maxIterations)
        external
        returns (uint256);

    function repay(address _poolToken, address _onBehalf, uint256 _amount) external;
    function repay(address underlying, uint256 amount, address onBehalf) external returns (uint256);

    function claimRewards(address[] calldata _poolTokens, bool _tradeForMorphoToken) external returns (uint256);
    function claimRewards(address[] calldata assets, address onBehalf)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts);
}
