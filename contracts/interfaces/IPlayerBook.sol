//==============================================================================
//  . _ _|_ _  _ |` _  _ _  _  .
//  || | | (/_| ~|~(_|(_(/__\  .
//==============================================================================
interface IPlayerBook {
    function getPlayerID(address _addr) external returns (uint256);

    function getPlayerName(uint256 _pID) external view returns (bytes32);

    function getPlayerAddr(uint256 _pID) external view returns (address);

    function getNameFee() external view returns (uint256);

    function getPlayerLAff(uint256 _pID) external view returns (uint256);

    function registerNameXnameFromDapp(
        address _addr,
        bytes32 _name,
        bytes32 _affCode,
        bool _all
    ) external payable returns (bool, uint256);

    function recordReferralCommission(address _referrer, uint256 _commission) external;
}
