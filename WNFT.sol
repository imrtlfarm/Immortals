pragma solidity 0.8.9;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

interface IAsset {
    // solhint-disable-previous-line no-empty-blocks
}

//need to make zapper work for relicquary
interface IZapComp {
    function composeZapIn(IAsset[] calldata tokens, uint[] calldata weights, bytes32 pid) external payable;
    function composeZapOut(IAsset[] calldata tokens, uint[] calldata amounts) external;
}



contract IMM_NFT is ERC721Enumerable, Ownable {
    IERC721 relic;
    IZapComp zapper;
    uint256 private nonce;

    //maps a relic id to the WNFT id that owns it
    mapping(uint256 => uint256) private _relicOwners;

    constructor(string memory name_, string memory symbol_, IERC721 relic_, IZapComp zapper_) ERC721(name_, symbol_) {
        relic = relic_;
        zapper = zapper_;
        //approves the zapper and only the zapper to spend tokens
        relic.setApprovalForAll(address(zapper), true);
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
        //this rly needs to check if sender is the owner of the wnft that the relic points to in _relicOwners 
        require(IERC721(this).ownerOf(_relicOwners[tokenId]) == sender);
        _;
    }

    //Implement a minting function that zaps in
    //Implement a burning function that zaps out
    //Implement the burning function mints a new NFT of some kind nirvana/rebirth theme

    function mint(address to, IAsset[] calldata tokens, uint[] calldata weights, bytes32 pid) internal returns (uint256 id) {
        id = nonce++;
        _safeMint(to, id);
        zapper.composeZapIn(tokens, weights, pid);

        //_relicOwners[relicId0] = id;
        //_relicOwners[relicId0] = id;
        //zap in and map the relic ids to the wnft id
    }

    function burn(uint256 tokenId, IAsset[] calldata tokens, uint[] calldata amounts) internal returns (bool) {
        _burn(tokenId);
        zapper.composeZapOut(tokens, amounts);
        return true;
        //zap out and kill the mapping entry
        //Mint a nirvana nft
    }

}