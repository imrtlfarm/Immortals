pragma solidity 0.8.9;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


interface IZapComp {
    function composeZapIn(uint loadOut, address[] calldata swapTargets, bytes[] calldata swapData, uint[] calldata mins) external payable returns(uint[] memory ids);
    function composeZapOut(uint[] memory relicIds, uint loadOut, address[][] memory swapTargets, bytes[][] memory swapData, uint[] calldata mins, address ogSender) external;
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
        //checks if sender owns the tokenId relic
        require(IERC721(this).ownerOf(_relicOwners[tokenId]) == sender);
        _;
    }


    //TODO: make it so the burning function mints a new NFT of some kind nirvana/rebirth theme

    function mint(address to, uint loadOut, address[] calldata swapTargets, bytes[] calldata swapData, uint[] calldata mins) internal returns (uint256 id) {
        id = nonce++;
        _safeMint(to, id);
        uint[] memory relicIds = zapper.composeZapIn(loadOut, swapTargets, swapData, mins);
        for(uint i=0;i<relicIds.length;i++){
            _relicOwners[relicIds[i]] = id;
        }

        
    }

    function burn(uint256 tokenId, uint[] memory relicIds, uint loadOut, address[][] memory swapTargets, bytes[][] memory swapData, uint[] calldata mins, address ogSender) internal returns (bool) {
        _burn(tokenId);
        zapper.composeZapOut(relicIds, loadOut, swapTargets, swapData, mins, ogSender);
        
        //zap out and kill the mapping entry
        for(uint i=0;i<relicIds.length;i++){
            delete _relicOwners[relicIds[i]];
        }
        //TODO: Mint a nirvana nft


        return true;
    }

}