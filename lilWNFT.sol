pragma solidity 0.8.9;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";


interface IZapComp {
    function composeZapIn(uint loadOut, address[] calldata swapTargets, bytes[] calldata swapData, uint[] calldata mins) external payable returns(uint[] memory ids);
    function composeZapOut(uint[] memory relicIds, uint loadOut, address[][] memory swapTargets, bytes[][] memory swapData, uint[] calldata mins, address ogSender) external;
}

interface IReliquary {
     function createRelicAndDeposit(
        address to,
        uint256 pid,
        uint256 amount
    ) external returns (uint256 id);

    function deposit(uint256 amount, uint256 _relicId) external;

    function withdraw(uint256 amount, uint256 _relicId) external;

    function harvest(uint256 _relicId) external;

    function withdrawAndHarvest(uint256 amount, uint256 _relicId) external;

    function emergencyWithdraw(uint256 _relicId) external; //maybe delete

    function positionForId(uint256 _relicId) external returns(uint256 amount,int256 rewardDebt,uint256 entry,uint256 poolId);
}

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transfer.selector, to, value)
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
        );
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(token.approve.selector, spender, value)
        );
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(
            token,
            abi.encodeWithSelector(
                token.approve.selector,
                spender,
                newAllowance
            )
        );
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(
                oldAllowance >= value,
                "SafeERC20: decreased allowance below zero"
            );
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(
                token,
                abi.encodeWithSelector(
                    token.approve.selector,
                    spender,
                    newAllowance
                )
            );
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata =
            address(token).functionCall(
                data,
                "SafeERC20: low-level call failed"
            );
        if (returndata.length > 0) {
            // Return data is optional
            // solhint-disable-next-line max-line-length
            require(
                abi.decode(returndata, (bool)),
                "SafeERC20: ERC20 operation did not succeed"
            );
        }
    }
}


contract IMM_NFT is ERC721Enumerable, Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;
    
    IERC721Enumerable public relic;
    uint256 private nonce;
    IERC20 public immutable OATH;

    //maps a relic id to the WNFT id that owns it
    mapping(uint256 => uint256) private _relicOwners;

    //mapping of WNFT id to list of relics that it owns
    mapping(uint256 => uint256[]) private _ownedRelics;

    constructor(string memory name_, string memory symbol_, IERC721Enumerable relic_, IERC20 _OATH) ERC721(name_, symbol_) {
        relic = relic_;
        OATH = _OATH;
        //approves the zapper and only the zapper to spend tokens
    }
    

    //figure out a way to make a transfer of zapper approval more secure if it is needed
    //owner will be multisig tho
    function SetApproveRelic(address to, bool approved) public onlyOwner {
        relic.setApprovalForAll(address(to), approved);
    }

    function ownerOfRelic(uint256 tokenId) public view returns(uint id){
        id = _relicOwners[tokenId];
    }

    modifier onlyOwnedRelic(uint256 tokenId, address sender) {
        //checks if sender owns the tokenId relic
        require(IERC721(this).ownerOf(_relicOwners[tokenId]) == sender, "Relic Not Owned");
        _;
    }
    modifier onlyOwnedRelics(uint256[] calldata tokenId, address sender) {
        //checks if sender owns the tokenId relics
        for(uint i=0;i<tokenId.length;i++){
            require(IERC721(this).ownerOf(_relicOwners[tokenId[i]]) == sender, "Relic Not Owned");
        }
        _;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
    //TODO: make it so the burning function mints a new NFT of some kind nirvana/rebirth theme
    //Could also just invert the color scheme or smth

    function mint(IERC20 LP) public returns (uint256 id) {
        id = nonce++;
        _safeMint(msg.sender, id);
        uint[4] memory relicIds;
        LP.approve(address(relic), uint256(2**256 - 1));
        relicIds[0] = IReliquary(address(relic)).createRelicAndDeposit(address(this),0,10);
        relicIds[1] = IReliquary(address(relic)).createRelicAndDeposit(address(this),0,11);
        relicIds[2] = IReliquary(address(relic)).createRelicAndDeposit(address(this),0,12);
        relicIds[3] = IReliquary(address(relic)).createRelicAndDeposit(address(this),0,13);

        for(uint i=0;i<relicIds.length;i++){
            _relicOwners[relicIds[i]] = id;
            _ownedRelics[id].push(relicIds[i]);
        }

        
    }

    function burn(uint256 tokenId, uint[] calldata relicIds, IERC20 LP) public onlyOwnedRelics(relicIds, msg.sender) returns (bool) {
        _burn(tokenId);
        IReliquary(address(relic)).withdrawAndHarvest(10, relicIds[0]);
        IReliquary(address(relic)).withdrawAndHarvest(11, relicIds[1]);
        IReliquary(address(relic)).withdrawAndHarvest(12, relicIds[2]);
        IReliquary(address(relic)).withdrawAndHarvest(13, relicIds[3]);
        
        //zap out and kill the mapping entry
        for(uint i=0;i<relicIds.length;i++){
            delete _relicOwners[relicIds[i]];
        }
        delete _ownedRelics[tokenId];
        //TODO: Mint a nirvana nft

        LP.safeTransfer(msg.sender, LP.balanceOf(address(this)));
        OATH.safeTransfer(msg.sender, OATH.balanceOf(address(this)));
        return true;
    }

    function harvest(uint256 tokenId) public onlyOwnedRelic(tokenId, msg.sender){
        for(uint i=0;i<_ownedRelics[tokenId].length;i++){
            IReliquary(address(relic)).harvest(_ownedRelics[tokenId][i]);
        }
        OATH.safeTransfer(msg.sender, OATH.balanceOf(address(this)));
    }

}