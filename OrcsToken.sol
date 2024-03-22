// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrcsToken is ERC20 {

    address public immutable GOVERNOR;

    /**
     * @notice the address of the airdropped zkSync reward token - will be address(0) if native currency
     */
    address public airdropToken;

    /**
     * @notice the amount of airdrop tokens that may be claimed in exchange for 1 * 10**18 $Orcs
     */
    uint256 public redeemValue; 
    
    /**
     * @notice if true (in the event of airdrop) minting will not be possible
     */
    bool public mintingDisabled;

    event BatchTransfer(address[] recipients, uint256[] amounts);
    event TokensPurchased(address indexed buyer, uint256 amount);
    event PostAirdropValueSet(address airdropTokenAddress, uint256 redeemValue);
    event ETHWithdrawn(address recipient, uint256 amount);
    event ERC20Withdrawn(address recipient, address token, uint256 amount);
    event TokensRedeemed(address indexed owner, uint256 tokensRedeemed, uint256 airdropTokensReceived);
    // event PriceChanged(uint256 newPrice);

    error OrcsToken__OnlyGovernor();
    error OrcsToken__BatchTransferArrayMismatch();
    error OrcsToken__PostAirdropValuesNotSet();
    error OrcsToken__TransferFailed();
    error OrcsToken__NotEnoughTokensToRedeem();
    error OrcsToken__MintingDisabled();
    error OrcsToken__RedeemValueAlreadySet();

    modifier onlyGovernor() {
        if(msg.sender != GOVERNOR) revert OrcsToken__OnlyGovernor();
        _;
    }

    constructor(address _governor) ERC20("$Orcs", "$ORCS") {
        GOVERNOR = _governor;
    }

    fallback() external payable {}
    receive() external payable {}

    function batchTransfer(address[] calldata _recipients, uint256[] calldata _amounts) external onlyGovernor {
        if (mintingDisabled) revert OrcsToken__MintingDisabled();
        if (_recipients.length != _amounts.length) revert OrcsToken__BatchTransferArrayMismatch();
        for (uint i; i < _recipients.length; ++i) {
            _mint(_recipients[i], _amounts[i]);
        }
        emit BatchTransfer(_recipients, _amounts);
    }

    function purchaseTokens() external payable {
        if (mintingDisabled) revert OrcsToken__MintingDisabled();
        require(msg.value > 0);
        _mint(msg.sender, msg.value);
        emit TokensPurchased(msg.sender, msg.value);
    }

    /**
     * @notice sets redeem value for $ORCS token following zkSync Airdrop
     * @notice disables minting so supply becomes capped at current supply
     * @dev _redeemValue must be calculated off-chain to avoid division/precision errors
     * @param _airdropToken address of airdrop token (zero address for ETH)
     * @param _redeemValue amount of airdrop token that can be claimed for 1 * 10**18 $Orcs
     */
    function setPostAirdropValue(address _airdropToken, uint256 _redeemValue) external onlyGovernor {
        if (redeemValue != 0) revert OrcsToken__RedeemValueAlreadySet();
        require(_redeemValue > 0);
        mintingDisabled = true;
        airdropToken = _airdropToken;
        redeemValue = _redeemValue;
        emit PostAirdropValueSet(_airdropToken, _redeemValue);
    }

    function redeemTokens(uint256 _amount) external {
        if (redeemValue == 0) revert OrcsToken__PostAirdropValuesNotSet();
        if (_amount < redeemValue) revert OrcsToken__NotEnoughTokensToRedeem();
        uint256 redeemAmount = _amount / redeemValue; 

        _burn(msg.sender, _amount);

        if (airdropToken == address(0)) {
            (bool success, ) = msg.sender.call{value: redeemAmount}("");
            if (!success) revert OrcsToken__TransferFailed();
        } else { 
            bool success = IERC20(airdropToken).transfer(msg.sender, redeemAmount);
            if (!success) revert OrcsToken__TransferFailed();
        }

        emit TokensRedeemed(msg.sender, _amount, redeemAmount);
    }

    function withdrawETH(address _recipient, uint256 _amount) external onlyGovernor {
        (bool success, ) = _recipient.call{value: _amount}("");
        if (!success) revert OrcsToken__TransferFailed();
        emit ETHWithdrawn(_recipient, _amount);
    }

    function withdrawERC20(address _recipient, address _token, uint256 _amount) external onlyGovernor {
        bool success = IERC20(_token).transfer(_recipient, _amount);
        if (!success) revert OrcsToken__TransferFailed();
        emit ERC20Withdrawn(_recipient, _token, _amount);
    }

}