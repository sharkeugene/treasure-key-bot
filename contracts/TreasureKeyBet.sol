// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "pantherswap-peripheral/contracts/interfaces/IPantherRouter02.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import "./interfaces/IStakingRewards.sol";
import "./interfaces/IWBNB.sol";
import "./interfaces/IPlayerBook.sol";
import "hardhat/console.sol";
import "./libraries/SafeMath.sol";
import "./libraries/NameFilter.sol";

/**
 * @title Treasure Key Bet
 *
 * WARNING:  THIS PRODUCT IS HIGHLY ADDICTIVE.  IF YOU HAVE AN ADDICTIVE NATURE.  DO NOT PLAY.
 */

//==============================================================================
//     _    _  _ _|_ _  .
//    (/_\/(/_| | | _\  .
//==============================================================================
contract F3Devents {
    // fired whenever a player registers a name
    event onNewName(
        uint256 indexed playerID,
        address indexed playerAddress,
        bytes32 indexed playerName,
        bool isNewPlayer,
        uint256 affiliateID,
        address affiliateAddress,
        bytes32 affiliateName,
        uint256 amountPaid,
        uint256 timeStamp
    );

    // fired at end of buy or reload
    event onEndTx(
        uint256 compressedData,
        uint256 compressedIDs,
        bytes32 playerName,
        address playerAddress,
        uint256 ethIn,
        uint256 keysBought,
        address winnerAddr,
        bytes32 winnerName,
        uint256 amountWon,
        uint256 devAmount,
        uint256 genAmount,
        uint256 potAmount
    );

    // fired whenever theres a withdraw
    event onWithdraw(
        uint256 indexed playerID,
        address playerAddress,
        bytes32 playerName,
        uint256 ethOut,
        uint256 timeStamp
    );

    // fired whenever a withdraw forces end round to be ran
    event onWithdrawAndDistribute(
        address playerAddress,
        bytes32 playerName,
        uint256 ethOut,
        uint256 compressedData,
        uint256 compressedIDs,
        address winnerAddr,
        bytes32 winnerName,
        uint256 amountWon,
        uint256 devAmount,
        uint256 genAmount
    );

    // (treasure key bet only) fired whenever a player tries a buy after round timer
    // hit zero, and causes end round to be ran.
    event onBuyAndDistribute(
        address playerAddress,
        bytes32 playerName,
        uint256 ethIn,
        uint256 compressedData,
        uint256 compressedIDs,
        address winnerAddr,
        bytes32 winnerName,
        uint256 amountWon,
        uint256 devAmount,
        uint256 genAmount
    );

    // fired whenever an affiliate is paid
    event onAffiliatePayout(
        uint256 indexed affiliateID,
        address affiliateAddress,
        bytes32 affiliateName,
        uint256 indexed roundID,
        uint256 indexed buyerID,
        uint256 amount,
        uint256 timeStamp
    );

    // (treasure key bet only) fired whenever a player tries a reload after round timer
    // hit zero, and causes end round to be ran.
    event onReLoadAndDistribute(
        address playerAddress,
        bytes32 playerName,
        uint256 compressedData,
        uint256 compressedIDs,
        address winnerAddr,
        bytes32 winnerName,
        uint256 amountWon,
        uint256 devAmount,
        uint256 genAmount
    );
}

//==============================================================================
//   _ _  _ _|_ _ _  __|_   _ _ _|_    _   .
//  (_(_)| | | | (_|(_ |   _\(/_ | |_||_)  .
//====================================|=========================================

contract modularLong is F3Devents {

}

contract TreasureKeyBet is modularLong, OwnableUpgradeable {
    using SafeMath for *;
    using NameFilter for string;
    using F3DKeysCalcLong for uint256;

    //==============================================================================
    //     _ _  _  |`. _     _ _ |_ | _  _  .
    //    (_(_)| |~|~|(_||_|| (_||_)|(/__\  .  (game settings)
    //=================_|===========================================================
    string public constant name = "Jungle Chest";
    string public constant symbol = "TREASURE";
    uint256 private constant rndInit_ = 1 hours; // round timer starts at this
    uint256 private constant rndInc_ = 90 seconds; // every full key purchased adds this much to the timer
    uint256 private constant rndMax_ = 52 weeks; // max length a round timer can be

    address private constant DEV = 0x6Aa9A4aaf122a440b5eA3036C020E562327A85Ed;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant BURN_TOKEN =
        0x1f546aD641B56b86fD9dCEAc473d1C7a357276B7;
    address private constant BURN_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
    address private constant PIRATE =
        0x63041a8770c4CFE8193D784f3Dc7826eAb5B7Fd2;
    address private constant PIRATE_BNB =
        0x3F2FC02441fE78217F08A9B7a3c0107380025347;
    IPantherRouter02 private constant ROUTER =
        IPantherRouter02(0x24f7C33ae5f77e2A9ECeed7EA858B4ca2fa1B7eC);

    IPlayerBook private PLAYER_BOOK;
    address private PIRATE_POOL;
    bool public activated_;

    //==============================================================================
    //     _| _ _|_ _    _ _ _|_    _   .
    //    (_|(_| | (_|  _\(/_ | |_||_)  .  (data used to store game info that changes)
    //=============================|================================================
    uint256 public rID_; // round id number / total rounds that have happened
    //****************
    // PLAYER DATA
    //****************
    mapping(address => uint256) public pIDxAddr_; // (addr => pID) returns player id by address
    mapping(bytes32 => uint256) public pIDxName_; // (name => pID) returns player id by name
    mapping(uint256 => F3Ddatasets.Player) public plyr_; // (pID => data) player data
    mapping(uint256 => mapping(uint256 => F3Ddatasets.PlayerRounds))
        public plyrRnds_; // (pID => rID => data) player round data by player id & round id
    mapping(uint256 => mapping(bytes32 => bool)) public plyrNames_; // (pID => name => bool) list of names a player owns.  (used so you can change your display name amongst any name you own)
    //****************
    // ROUND DATA
    //****************
    mapping(uint256 => F3Ddatasets.Round) public round_; // (rID => data) round data
    //****************
    // FEE DATA
    //****************
    F3Ddatasets.KeyFee public fees_; // fee distribution by holder
    F3Ddatasets.PotSplit public potSplit_; // fees pot split distribution

    //==============================================================================
    //     _ _  _  __|_ _    __|_ _  _  .
    //    (_(_)| |_\ | | |_|(_ | (_)|   .  (initial data setup upon contract deploy)
    //==============================================================================
    function initialize(address _book, address _pool) external initializer {
        __Ownable_init();
        require(owner() != address(0), "owner must be set");
        activated_ = false;

        // Key allocation percentages
        // F3Dx + (Pot, Share, Developer)
        fees_ = F3Ddatasets.KeyFee(24, 5, 1, 60, 5, 5); // Should add up to 100%
        // 60% - Added to the Treasure Chest
        // 24% - Redistribute to earlier key buyers of this round
        // 5% - Redistribute to affliates
        // 5% - Added to $PIRATE Pool where stakers can earn these rewards
        // 5% - Development Fund
        // 1% - Purchase $PANTHER to burn

        // Pot allocation percentages
        // (WIN, DEV)
        potSplit_ = F3Ddatasets.PotSplit(50, 48, 2); // Add up to 100%
        // 50% - Winner (last person to buy key before round ends)
        // 48% - Added to the next round's Treasure Chest
        // 2% - Marketing and Ecosystem Fund

        PLAYER_BOOK = IPlayerBook(_book);
        PIRATE_POOL = _pool;
    }

    //==============================================================================
    //     _ _  _  _|. |`. _  _ _  .
    //    | | |(_)(_||~|~|(/_| _\  .  (these are safety checks)
    //==============================================================================
    /**
     * @dev used to make sure no one can interact with contract until it has
     * been activated.
     */
    modifier isActivated() {
        require(activated_ == true, "its not ready yet.");
        _;
    }

    /**
     * @dev prevents contracts from interacting with treasure key bet
     */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {
            _codeLength := extcodesize(_addr)
        }
        require(_codeLength == 0, "sorry humans only");
        _;
    }

    modifier isHumanV2() {
        require(tx.origin == msg.sender, "sorry humans only");
        _;
    }

    /**
     * @dev sets boundaries for incoming tx
     */
    modifier isWithinLimits(uint256 _eth) {
        require(_eth >= 1000000000, "pocket lint: not a valid currency");
        require(_eth <= 100000000000000000000000, "no cz, no");
        _;
    }

    //==============================================================================
    //     _    |_ |. _   |`    _  __|_. _  _  _  .
    //    |_)|_||_)||(_  ~|~|_|| |(_ | |(_)| |_\  .  (use these to interact with contract)
    //====|=========================================================================
    /**
     * @dev emergency buy
     */
    fallback()
        external
        payable
        isActivated()
        isHuman()
        isWithinLimits(msg.value)
    {
        // set up our tx event data and determine if player is new or not
        F3Ddatasets.EventReturns memory _eventData_;
        _eventData_ = determinePID(_eventData_);

        // fetch player id
        uint256 _pID = pIDxAddr_[msg.sender];

        // buy core
        // We do not insert an affiliate here?
        buyCore(_pID, uint256(0), _eventData_);
    }

    /**
     * @dev converts all incoming ethereum to keys.
     * -functionhash- 0x8f38f309 (using ID for affiliate)
     * -functionhash- 0x98a0871d (using address for affiliate)
     * -functionhash- 0xa65b37a1 (using name for affiliate)
     * Removed 2 other functions that uses ID or Address for affliate, because no point
     * We will be using only NAME for affiliates
     * @param _affCode the ID/address/name of the player who gets the affiliate fee
     */

    function buyXname(bytes32 _affCode)
        public
        payable
        isActivated()
        isHuman()
        isWithinLimits(msg.value)
    {
        // set up our tx event data and determine if player is new or not
        F3Ddatasets.EventReturns memory _eventData_;
        _eventData_ = determinePID(_eventData_);

        // fetch player id
        uint256 _pID = pIDxAddr_[msg.sender];

        // manage affiliate residuals
        uint256 _affID;
        // if no affiliate code was given or player tried to use their own, lolz
        if (_affCode == "" || _affCode == plyr_[_pID].name) {
            // use last stored affiliate code
            _affID = plyr_[_pID].laff;

            // if affiliate code was given
        } else {
            // get affiliate ID from aff Code
            _affID = pIDxName_[_affCode];

            // if affID is not the same as previously stored
            if (_affID != plyr_[_pID].laff) {
                // update last affiliate
                plyr_[_pID].laff = _affID;
            }
        }

        // buy core
        buyCore(_pID, _affID, _eventData_);
    }

    /**
     * @dev essentially the same as buy, but instead of you sending ether
     * from your wallet, it uses your unwithdrawn earnings.
     * -functionhash- 0x349cdcac (using ID for affiliate)
     * -functionhash- 0x82bfc739 (using address for affiliate)
     * -functionhash- 0x079ce327 (using name for affiliate)
     * Also have removed the other 2 functions that uses ID or address for affiliates
     * @param _affCode the ID/address/name of the player who gets the affiliate fee
     * @param _eth amount of earnings to use (remainder returned to gen vault)
     */

    function reLoadXname(bytes32 _affCode, uint256 _eth)
        public
        isActivated()
        isHuman()
        isWithinLimits(_eth)
    {
        // set up our tx event data
        F3Ddatasets.EventReturns memory _eventData_;

        // fetch player ID
        uint256 _pID = pIDxAddr_[msg.sender];

        // manage affiliate residuals
        uint256 _affID;
        // if no affiliate code was given or player tried to use their own, lolz
        if (_affCode == "" || _affCode == plyr_[_pID].name) {
            // use last stored affiliate code
            _affID = plyr_[_pID].laff;

            // if affiliate code was given
        } else {
            // get affiliate ID from aff Code
            _affID = pIDxName_[_affCode];

            // if affID is not the same as previously stored
            if (_affID != plyr_[_pID].laff) {
                // update last affiliate
                plyr_[_pID].laff = _affID;
            }
        }

        // reload core
        reLoadCore(_pID, _affID, _eth, _eventData_);
    }

    /**
     * @dev withdraws all of your earnings.
     * -functionhash- 0x3ccfd60b
     */
    function withdraw() public isActivated() isHuman() {
        // setup local rID
        uint256 _rID = rID_;

        // grab time
        uint256 _now = block.timestamp;

        // fetch player ID
        uint256 _pID = pIDxAddr_[msg.sender];

        // setup temp var for player eth
        uint256 _eth;

        // check to see if round has ended and no one has run round end yet
        if (
            _now > round_[_rID].end &&
            round_[_rID].ended == false &&
            round_[_rID].plyr != 0
        ) {
            // set up our tx event data
            F3Ddatasets.EventReturns memory _eventData_;

            // end the round (distributes pot)
            round_[_rID].ended = true;
            _eventData_ = endRound(_eventData_);

            // get their earnings
            _eth = withdrawEarnings(_pID);

            // gib moni
            if (_eth > 0) payable(plyr_[_pID].addr).transfer(_eth);

            // build event data
            _eventData_.compressedData =
                _eventData_.compressedData +
                (_now * 1000000000000000000);
            _eventData_.compressedIDs = _eventData_.compressedIDs + _pID;

            // fire withdraw and distribute event
            emit F3Devents.onWithdrawAndDistribute(
                msg.sender,
                plyr_[_pID].name,
                _eth,
                _eventData_.compressedData,
                _eventData_.compressedIDs,
                _eventData_.winnerAddr,
                _eventData_.winnerName,
                _eventData_.amountWon,
                _eventData_.devAmount,
                _eventData_.genAmount
            );

            // in any other situation
        } else {
            // get their earnings
            _eth = withdrawEarnings(_pID);

            // gib moni
            if (_eth > 0) payable(plyr_[_pID].addr).transfer(_eth);

            // fire withdraw event
            emit F3Devents.onWithdraw(
                _pID,
                msg.sender,
                plyr_[_pID].name,
                _eth,
                _now
            );
        }
    }

    /**
     * @dev use these to register names.  they are just wrappers that will send the
     * registration requests to the PlayerBook contract.  So registering here is the
     * same as registering there.  UI will always display the last name you registered.
     * - must pay a registration fee.
     * - name must be unique
     * - names will be converted to lowercase
     * - name cannot start or end with a space
     * - cannot have more than 1 space in a row
     * - cannot be only numbers
     * - cannot start with 0x
     * - name must be at least 1 char
     * - max length of 32 characters long
     * - allowed characters: a-z, 0-9, and space
     * @param _nameString players desired name
     * @param _all set to true if you want this to push your info to all games
     * Need to specify an affiliate code that is provided by referrer
     * (this might cost a lot of gas)
     */

    function registerNameXname(
        string memory _nameString,
        bytes32 _affCode,
        bool _all
    ) public payable isHuman() {
        bytes32 _name = _nameString.nameFilter();
        address _addr = msg.sender;
        uint256 _paid = msg.value;
        (bool _isNewPlayer, uint256 _affID) =
            PLAYER_BOOK.registerNameXnameFromDapp{value: msg.value}(
                msg.sender,
                _name,
                _affCode,
                _all
            );

        uint256 _pID = pIDxAddr_[_addr];

        // fire event
        emit F3Devents.onNewName(
            _pID,
            _addr,
            _name,
            _isNewPlayer,
            _affID,
            plyr_[_affID].addr,
            plyr_[_affID].name,
            _paid,
            now
        );
    }

    function setPiratePool(address _pool) external onlyOwner {
        require(address(_pool) != address(0), "zero address");
        PIRATE_POOL = _pool;
    }

    //==============================================================================
    //     _  _ _|__|_ _  _ _  .
    //    (_|(/_ |  | (/_| _\  . (for UI & viewing things on etherscan)
    //=====_|=======================================================================
    /**
     * @dev return the price buyer will pay for next 1 individual key.
     * -functionhash- 0x018a25e8
     * @return price for next key bought (in wei format)
     */
    function getBuyPrice() public view returns (uint256) {
        // setup local rID
        uint256 _rID = rID_;

        // grab time
        uint256 _now = block.timestamp;

        // are we in a round?
        if (
            _now > round_[_rID].strt &&
            (_now <= round_[_rID].end ||
                (_now > round_[_rID].end && round_[_rID].plyr == 0))
        )
            return (
                (round_[_rID].keys.add(1000000000000000000)).ethRec(
                    1000000000000000000
                )
            );
        // rounds over.  need price for new round
        else return (100000000000000); // init
    }

    /**
     * @dev returns time left.  dont spam this, you'll ddos yourself from your node
     * provider
     * -functionhash- 0xc7e284b8
     * @return time left in seconds
     */
    function getTimeLeft() public view returns (uint256) {
        // setup local rID
        uint256 _rID = rID_;

        // grab time
        uint256 _now = block.timestamp;

        if (_now < round_[_rID].end)
            if (_now > round_[_rID].strt) return ((round_[_rID].end).sub(_now));
            else return ((round_[_rID].strt).sub(_now));
        else return (0);
    }

    /**
     * @dev returns player earnings per vaults
     * -functionhash- 0x63066434
     * @return winnings vault
     * @return general vault
     */
    function getPlayerVaults(uint256 _pID)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        // setup local rID
        uint256 _rID = rID_;

        // if round has ended.  but round end has not been run (so contract has not distributed winnings)
        if (
            block.timestamp > round_[_rID].end &&
            round_[_rID].ended == false &&
            round_[_rID].plyr != 0
        ) {
            return (
                plyr_[_pID].win,
                (plyr_[_pID].gen).add(
                    getPlayerVaultsHelper(_pID, _rID).sub(
                        plyrRnds_[_pID][_rID].mask
                    )
                ),
                plyr_[_pID].aff
            );
            // if round is still going on, or round has ended and round end has been ran
        } else {
            return (
                plyr_[_pID].win,
                (plyr_[_pID].gen).add(
                    calcUnMaskedEarnings(_pID, plyr_[_pID].lrnd)
                ),
                plyr_[_pID].aff
            );
        }
    }

    /**
     * solidity hates stack limits.  this lets us avoid that hate
     */
    function getPlayerVaultsHelper(uint256 _pID, uint256 _rID)
        private
        view
        returns (uint256)
    {
        return (
            ((
                (
                    (round_[_rID].mask).add(
                        (
                            (((round_[_rID].pot).mul(50)).div(100)).mul(
                                1000000000000000000
                            )
                        ) / (round_[_rID].keys)
                    )
                )
                    .mul(plyrRnds_[_pID][_rID].keys)
            ) / 1000000000000000000)
        );
    }

    /**
     * @dev returns all current round info needed for front end
     * -functionhash- 0x747dff42
     * @return eth invested during ICO phase
     * @return round id
     * @return total keys for round
     * @return time round ends
     * @return time round started
     * @return current pot
     * @return player ID in lead
     * @return current player in leads address
     * @return current player in leads name
     */
    function getCurrentRoundInfo()
        isHumanV2()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            bytes32
        )
    {
        // setup local rID
        uint256 _rID = rID_;

        return (
            round_[_rID].ico, //0
            _rID, //1
            round_[_rID].keys, //2
            round_[_rID].end, //3
            round_[_rID].strt, //4
            round_[_rID].pot, //5
            // (round_[_rID].plyr * 10), //6
            round_[_rID].plyr, //6
            plyr_[round_[_rID].plyr].addr, //7
            plyr_[round_[_rID].plyr].name //8
        );
    }

     /**
     * @dev returns all past round info needed for front end
     * -functionhash- 0x747dff42
     * @return eth invested during ICO phase
     * @return round id
     * @return total keys for round
     * @return time round ends
     * @return time round started
     * @return current pot
     * @return player ID in lead
     * @return current player in leads address
     * @return current player in leads name
     */
    function getPastRoundInfo(uint256 roundId)
        isHumanV2()
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            bytes32
        )
    {
        // setup local rID
        uint256 _rID = roundId;

        return (
            round_[_rID].ico, //0
            _rID, //1
            round_[_rID].keys, //2
            round_[_rID].end, //3
            round_[_rID].strt, //4
            round_[_rID].pot, //5
            // (round_[_rID].plyr * 10), //6
            round_[_rID].plyr, //6
            plyr_[round_[_rID].plyr].addr, //7
            plyr_[round_[_rID].plyr].name //8
        );
    }

    /**
     * @dev returns player info based on address.  if no address is given, it will
     * use msg.sender
     * -functionhash- 0xee0b5d8b
     * @param _addr address of the player you want to lookup
     * @return player ID
     * @return player name
     * @return keys owned (current round)
     * @return winnings vault
     * @return general vault
     * @return affliate vault
     * @return player round eth
     */
    function getPlayerInfoByAddress(address _addr)
        isHumanV2()
        public
        view
        returns (
            uint256,
            bytes32,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        // setup local rID
        uint256 _rID = rID_;

        if (_addr == address(0)) {
            _addr == msg.sender;
        }
        uint256 _pID = pIDxAddr_[_addr];

        return (
            _pID, //0
            plyr_[_pID].name, //1
            plyrRnds_[_pID][_rID].keys, //2
            plyr_[_pID].win, //3
            (plyr_[_pID].gen).add(calcUnMaskedEarnings(_pID, plyr_[_pID].lrnd)), //4
            plyr_[_pID].aff, //5
            plyrRnds_[_pID][_rID].eth //6
        );
    }

    //==============================================================================
    //     _ _  _ _   | _  _ . _  .
    //    (_(_)| (/_  |(_)(_||(_  . (this + tools + calcs + modules = our softwares engine)
    //=====================_|=======================================================
    /**
     * @dev logic runs whenever a buy order is executed.  determines how to handle
     * incoming eth depending on if we are in an active round or not
     */
    function buyCore(
        uint256 _pID,
        uint256 _affID,
        F3Ddatasets.EventReturns memory _eventData_
    ) private {
        // setup local rID
        uint256 _rID = rID_;

        // grab time
        uint256 _now = block.timestamp;

        // if round is active
        if (
            _now > round_[_rID].strt &&
            (_now <= round_[_rID].end ||
                (_now > round_[_rID].end && round_[_rID].plyr == 0))
        ) {
            // call core
            core(_rID, _pID, msg.value, _affID, _eventData_);

            // if round is not active
        } else {
            // check to see if end round needs to be ran
            if (_now > round_[_rID].end && round_[_rID].ended == false) {
                // end the round (distributes pot) & start new round
                round_[_rID].ended = true;
                _eventData_ = endRound(_eventData_);

                // build event data
                _eventData_.compressedData =
                    _eventData_.compressedData +
                    (_now * 1000000000000000000);
                _eventData_.compressedIDs = _eventData_.compressedIDs + _pID;

                // fire buy and distribute event
                emit F3Devents.onBuyAndDistribute(
                    msg.sender,
                    plyr_[_pID].name,
                    msg.value,
                    _eventData_.compressedData,
                    _eventData_.compressedIDs,
                    _eventData_.winnerAddr,
                    _eventData_.winnerName,
                    _eventData_.amountWon,
                    _eventData_.devAmount,
                    _eventData_.genAmount
                );
            }

            // put eth in players vault
            plyr_[_pID].gen = plyr_[_pID].gen.add(msg.value);
        }
    }

    /**
     * @dev logic runs whenever a reload order is executed.  determines how to handle
     * incoming eth depending on if we are in an active round or not
     */
    function reLoadCore(
        uint256 _pID,
        uint256 _affID,
        uint256 _eth,
        F3Ddatasets.EventReturns memory _eventData_
    ) private {
        // setup local rID
        uint256 _rID = rID_;

        // grab time
        uint256 _now = block.timestamp;

        // if round is active
        if (
            _now > round_[_rID].strt &&
            (_now <= round_[_rID].end ||
                (_now > round_[_rID].end && round_[_rID].plyr == 0))
        ) {
            // get earnings from all vaults and return unused to gen vault
            // because we use a custom safemath library.  this will throw if player
            // tried to spend more eth than they have.
            plyr_[_pID].gen = withdrawEarnings(_pID).sub(_eth);

            // call core
            core(_rID, _pID, _eth, _affID, _eventData_);

            // if round is not active and end round needs to be ran
        } else if (_now > round_[_rID].end && round_[_rID].ended == false) {
            // end the round (distributes pot) & start new round
            round_[_rID].ended = true;
            _eventData_ = endRound(_eventData_);

            // build event data
            _eventData_.compressedData =
                _eventData_.compressedData +
                (_now * 1000000000000000000);
            _eventData_.compressedIDs = _eventData_.compressedIDs + _pID;

            // fire buy and distribute event
            emit F3Devents.onReLoadAndDistribute(
                msg.sender,
                plyr_[_pID].name,
                _eventData_.compressedData,
                _eventData_.compressedIDs,
                _eventData_.winnerAddr,
                _eventData_.winnerName,
                _eventData_.amountWon,
                _eventData_.devAmount,
                _eventData_.genAmount
            );
        }
    }

    /**
     * @dev this is the core logic for any buy/reload that happens while a round
     * is live.
     */
    function core(
        uint256 _rID,
        uint256 _pID,
        uint256 _eth,
        uint256 _affID,
        F3Ddatasets.EventReturns memory _eventData_
    ) private {
        // if player is new to round
        if (plyrRnds_[_pID][_rID].keys == 0)
            _eventData_ = managePlayer(_pID, _eventData_);

        // early round eth limiter
        // limit 50 persons, 50 BNB
        if (
            round_[_rID].eth < 50000000000000000000 &&
            plyrRnds_[_pID][_rID].eth.add(_eth) > 1000000000000000000
        ) {
            uint256 _availableLimit =
                (1000000000000000000).sub(plyrRnds_[_pID][_rID].eth);
            uint256 _refund = _eth.sub(_availableLimit);
            plyr_[_pID].gen = plyr_[_pID].gen.add(_refund);
            _eth = _availableLimit;
        }

        // if eth left is greater than min eth allowed (sorry no pocket lint)
        if (_eth > 1000000000) {
            // mint the new keys
            uint256 _keys = (round_[_rID].eth).keysRec(_eth);

            // if they bought at least 1 whole key
            if (_keys >= 1000000000000000000) {
                updateTimer(_keys, _rID);

                // set new leaders
                if (round_[_rID].plyr != _pID) round_[_rID].plyr = _pID;

                // set the new leader bool to true
                _eventData_.compressedData = _eventData_.compressedData + 100;
            }

            // update player
            plyrRnds_[_pID][_rID].keys = _keys.add(plyrRnds_[_pID][_rID].keys);
            plyrRnds_[_pID][_rID].eth = _eth.add(plyrRnds_[_pID][_rID].eth);

            // update round
            round_[_rID].keys = _keys.add(round_[_rID].keys);
            round_[_rID].eth = _eth.add(round_[_rID].eth);

            // distribute eth
            _eventData_ = distributeExternal(
                _eth,
                _rID,
                _pID,
                _affID,
                _eventData_
            );
            _eventData_ = distributeInternal(
                _rID,
                _pID,
                _eth,
                _keys,
                _affID,
                _eventData_
            );

            // call end tx function to fire end tx event.
            endTx(_pID, _eth, _keys, _eventData_);
        }
    }

    //==============================================================================
    //     _ _ | _   | _ _|_ _  _ _  .
    //    (_(_||(_|_||(_| | (_)| _\  .
    //==============================================================================
    /**
     * @dev calculates unmasked earnings (just calculates, does not update mask)
     * @return earnings in wei format
     */
    function calcUnMaskedEarnings(uint256 _pID, uint256 _rIDlast)
        private
        view
        returns (uint256)
    {
        return (
            (((round_[_rIDlast].mask).mul(plyrRnds_[_pID][_rIDlast].keys)) /
                (1000000000000000000))
                .sub(plyrRnds_[_pID][_rIDlast].mask)
        );
    }

    /**
     * @dev returns the amount of keys you would get given an amount of eth.
     * -functionhash- 0xce89c80c
     * @param _rID round ID you want price for
     * @param _eth amount of eth sent in
     * @return keys received
     */
    function calcKeysReceived(uint256 _rID, uint256 _eth)
        public
        view
        returns (uint256)
    {
        // grab time
        uint256 _now = block.timestamp;

        // are we in a round?
        if (
            _now > round_[_rID].strt &&
            (_now <= round_[_rID].end ||
                (_now > round_[_rID].end && round_[_rID].plyr == 0))
        ) return ((round_[_rID].eth).keysRec(_eth));
        // rounds over.  need keys for new round
        else return ((_eth).keys());
    }

    /**
     * @dev returns current eth price for X keys.
     * -functionhash- 0xcf808000
     * @param _keys number of keys desired (in 18 decimal format)
     * @return amount of eth needed to send
     */
    function iWantXKeys(uint256 _keys) public view returns (uint256) {
        // setup local rID
        uint256 _rID = rID_;

        // grab time
        uint256 _now = block.timestamp;

        // are we in a round?
        if (
            _now > round_[_rID].strt &&
            (_now <= round_[_rID].end ||
                (_now > round_[_rID].end && round_[_rID].plyr == 0))
        ) return ((round_[_rID].keys.add(_keys)).ethRec(_keys));
        // rounds over.  need price for new round
        else return ((_keys).eth());
    }

    //==============================================================================
    //    _|_ _  _ | _  .
    //     | (_)(_)|_\  .
    //==============================================================================
    /**
     * @dev receives name/player info from names contract
     */
    function receivePlayerInfo(
        uint256 _pID,
        address _addr,
        bytes32 _name,
        uint256 _laff
    ) external {
        require(
            msg.sender == address(PLAYER_BOOK),
            "your not playerNames contract... hmmm.."
        );
        if (pIDxAddr_[_addr] != _pID) pIDxAddr_[_addr] = _pID;
        if (pIDxName_[_name] != _pID) pIDxName_[_name] = _pID;
        if (plyr_[_pID].addr != _addr) plyr_[_pID].addr = _addr;
        if (plyr_[_pID].name != _name) plyr_[_pID].name = _name;
        if (plyr_[_pID].laff != _laff) plyr_[_pID].laff = _laff;
        if (plyrNames_[_pID][_name] == false) plyrNames_[_pID][_name] = true;
    }

    /**
     * @dev receives entire player name list
     */
    function receivePlayerNameList(uint256 _pID, bytes32 _name) external {
        require(
            msg.sender == address(PLAYER_BOOK),
            "your not playerNames contract... hmmm.."
        );
        if (plyrNames_[_pID][_name] == false) plyrNames_[_pID][_name] = true;
    }

    /**
     * @dev gets existing or registers new pID.  use this when a player may be new
     * @return pID
     */
    function determinePID(F3Ddatasets.EventReturns memory _eventData_)
        private
        returns (F3Ddatasets.EventReturns memory)
    {
        uint256 _pID = pIDxAddr_[msg.sender];
        // if player is new to this version of treasure key bet
        if (_pID == 0) {
            // grab their player ID, name, from player names contract
            _pID = PLAYER_BOOK.getPlayerID(msg.sender);
            bytes32 _name = PLAYER_BOOK.getPlayerName(_pID);
            uint256 _laff = PLAYER_BOOK.getPlayerLAff(_pID);

            // set up player account
            pIDxAddr_[msg.sender] = _pID;
            plyr_[_pID].addr = msg.sender;

            if (_name != "") {
                pIDxName_[_name] = _pID;
                plyr_[_pID].name = _name;
                plyrNames_[_pID][_name] = true;
            }

            if (_laff != 0 && _laff != _pID) plyr_[_pID].laff = _laff;

            // set the new player bool to true
            _eventData_.compressedData = _eventData_.compressedData + 1;
        }
        return (_eventData_);
    }

    /**
     * @dev decides if round end needs to be run & new round started.  and if
     * player unmasked earnings from previously played rounds need to be moved.
     */
    function managePlayer(
        uint256 _pID,
        F3Ddatasets.EventReturns memory _eventData_
    ) private returns (F3Ddatasets.EventReturns memory) {
        // if player has played a previous round, move their unmasked earnings
        // from that round to gen vault.
        if (plyr_[_pID].lrnd != 0) updateGenVault(_pID, plyr_[_pID].lrnd);

        // update player's last round played
        plyr_[_pID].lrnd = rID_;

        // set the joined round bool to true
        _eventData_.compressedData = _eventData_.compressedData + 10;

        return (_eventData_);
    }

    /**
     * @dev ends the round. manages paying out winner/splitting up pot
     */
    function endRound(F3Ddatasets.EventReturns memory _eventData_)
        private
        returns (F3Ddatasets.EventReturns memory)
    {
        // win, next, pool

        // setup local rID
        uint256 _rID = rID_;

        // grab our winning player
        uint256 _winPID = round_[_rID].plyr;

        // grab our pot amount
        uint256 _pot = round_[_rID].pot;
        console.log("Total pot amount", _pot);
        // calculate our winner share and developer rewards
        uint256 _win = (_pot.mul(potSplit_.win)).div(100); // 50% to winner
        uint256 _dev = (_pot.mul(potSplit_.dev)).div(100); // 2% to dev
        _pot = (_pot.sub(_win)).sub(_dev); // calc remaining amount to pot for next round

        // pay out to winner
        // payable(AwardPool).transfer(_win);
        plyr_[_winPID].win = _win.add(plyr_[_winPID].win);

        // pay to devs
        payable(DEV).transfer(_dev);

        // ended this pot
        // payable(AwardPool).transfer(_pot);

        // prepare event data
        _eventData_.compressedData =
            _eventData_.compressedData +
            (round_[_rID].end * 1000000);
        _eventData_.compressedIDs =
            _eventData_.compressedIDs +
            (_winPID * 100000000000000000000000000);
        _eventData_.winnerAddr = plyr_[_winPID].addr;
        _eventData_.winnerName = plyr_[_winPID].name;
        _eventData_.amountWon = _win;
        _eventData_.potAmount = _pot;
        _eventData_.devAmount = _dev;
        // Ended pot, and hence put the rest of the pot into this
        // _eventData_.newPot = _pot;

        // start next round
        rID_++;
        _rID++;
        round_[_rID].strt = block.timestamp;
        round_[_rID].end = block.timestamp.add(rndInit_);
        round_[_rID].pot = _pot;

        return (_eventData_);
    }

    /**
     * @dev moves any unmasked earnings to gen vault.  updates earnings mask
     */
    function updateGenVault(uint256 _pID, uint256 _rIDlast) private {
        uint256 _earnings = calcUnMaskedEarnings(_pID, _rIDlast);
        if (_earnings > 0) {
            // put in gen vault
            plyr_[_pID].gen = _earnings.add(plyr_[_pID].gen);
            // zero out their earnings by updating mask
            plyrRnds_[_pID][_rIDlast].mask = _earnings.add(
                plyrRnds_[_pID][_rIDlast].mask
            );
        }
    }

    /**
     * @dev updates round timer based on number of whole keys bought.
     */
    function updateTimer(uint256 _keys, uint256 _rID) private {
        // grab time
        uint256 _now = block.timestamp;

        // calculate time based on number of keys bought
        uint256 _newTime;
        if (_now > round_[_rID].end && round_[_rID].plyr == 0) {
            console.log("Going If");
            _newTime = (((_keys) / (1000000000000000000)).mul(rndInc_)).add(
                _now
            );
        } else {
            console.log("Going else");
            _newTime = (((_keys) / (1000000000000000000)).mul(rndInc_)).add(
                round_[_rID].end
            );
        }
        // compare to max and set new end time
        console.log(_newTime, "_newTime");
        console.log((rndMax_).add(_now), "(rndMax_).add(_now)");
        if (_newTime < (rndMax_).add(_now)) round_[_rID].end = _newTime;
        else round_[_rID].end = rndMax_.add(_now);
    }

    /**
     * @dev distributes eth based on fees to dev
     */
    function distributeExternal(
        uint256 _eth,
        uint256 _rID,
        uint256 _pID,
        uint256 _affID,
        F3Ddatasets.EventReturns memory _eventData_
    ) private returns (F3Ddatasets.EventReturns memory) {
        // pay 5% out to developer
        uint256 _dev = (_eth.mul(fees_.dev)).div(100);
        // burn 1% of target tokens
        uint256 _burn = (_eth.mul(fees_.burn)).div(100);
        // pay 5% to be placed in pirate pool
        uint256 _pool = (_eth.mul(fees_.pool)).div(100);
        // pay 5% to affliates
        uint256 _aff = (_eth.mul(fees_.aff)).div(100);

        // decide what to do with affiliate share of fees
        // affiliate must not be self, and must have a name registered
        // if affiliate exists, we pay affiliate fees to affiliate pot
        if (_affID != _pID && plyr_[_affID].name != "") {
            // adding affiliate amounts to player affiliate pot
            plyr_[_affID].aff = _aff.add(plyr_[_affID].aff);

            // record commissions so we can refer to it next time
            PLAYER_BOOK.recordReferralCommission(plyr_[_affID].addr, _aff);

            emit F3Devents.onAffiliatePayout(
                _affID,
                plyr_[_affID].addr,
                plyr_[_affID].name,
                _rID,
                _pID,
                _aff,
                now
            );
        }

        // place _pool amount into our $PIRATE pool
        uint256 sellAmount = _pool.div(2);
        uint pirateAmount = _swap(WBNB, sellAmount, PIRATE, address(this));
        uint256 before = IBEP20(WBNB).balanceOf(address(this));
        IWBNB(WBNB).deposit{value: _pool.sub(sellAmount)}();
        uint256 afterWBNB = IBEP20(WBNB).balanceOf(address(this)).sub(before);
        
        _approveTokenIfNeeded(WBNB);
        _approveTokenIfNeeded(PIRATE);
        console.log("_pool", _pool);
        console.log("_pool.sub(sellAmount)", _pool.sub(sellAmount));
        console.log("pirateAmount", pirateAmount);
        ROUTER.addLiquidity(WBNB, PIRATE, afterWBNB, pirateAmount, 0, 0, address(this), block.timestamp);
        uint256 pirateBNBAmount = IBEP20(PIRATE_BNB).balanceOf(address(this));
        console.log("pirateBNBAmount", pirateBNBAmount);
        IBEP20(PIRATE_BNB).transfer(PIRATE_POOL, pirateBNBAmount);
        IStakingRewards(PIRATE_POOL).notifyRewardAmount(pirateBNBAmount);

        // transfer _dev amount to developer
        payable(DEV).transfer(_dev);

        // swap _burn amount into target token, and burn it
        address[] memory path;
        path = new address[](2);
        path[0] = WBNB;
        path[1] = BURN_TOKEN;

        ROUTER.swapExactETHForTokensSupportingFeeOnTransferTokens{value: _burn}(
            0,
            path,
            address(this),
            block.timestamp
        );
        IBEP20(BURN_TOKEN).transfer(
            BURN_ADDRESS,
            IBEP20(BURN_TOKEN).balanceOf(address(this))
        );

        // set up event data
        _eventData_.devAmount = _dev.add(_eventData_.devAmount);

        return (_eventData_);
    }

    /**
     * @dev distributes eth based on fees to gen and pot
     */
    function distributeInternal(
        uint256 _rID,
        uint256 _pID,
        uint256 _eth,
        uint256 _keys,
        uint256 _affID,
        F3Ddatasets.EventReturns memory _eventData_
    ) private returns (F3Ddatasets.EventReturns memory) {
        // calculate gen share
        uint256 _gen = (_eth.mul(fees_.gen)) / 100;
        uint256 _aff = (_eth.mul(fees_.aff)).div(100);
        bool hasAffiliate = _affID != _pID && plyr_[_affID].name != "";
        
        // if no affiliate was registered, we add the affiliate fees back to general vault
        if (!hasAffiliate) {
            _gen.add(_aff);
        }

        // update eth balance (eth = eth - dev share)
        // _eth = _eth.sub((_eth.mul(fees_.dev)).div(100));
        // _eth = (_eth.mul(fees_.pot)).div(100);

        // calculate pot
        uint256 _pot = (_eth.mul(fees_.pot)) / 100;
        // uint256 _pot = _eth.sub(_gen);

        // distribute gen share (thats what updateMasks() does) and adjust
        // balances for dust.
        uint256 _dust = updateMasks(_rID, _pID, _gen, _keys);
        if (_dust > 0) _gen = _gen.sub(_dust);

        // add eth to pot
        round_[_rID].pot = _pot.add(_dust).add(round_[_rID].pot);

        // set up event data
        _eventData_.genAmount = _gen.add(_eventData_.genAmount);
        _eventData_.potAmount = _pot;

        return (_eventData_);
    }

    /**
     * @dev updates masks for round and player when keys are bought
     * @return dust left over
     */
    function updateMasks(
        uint256 _rID,
        uint256 _pID,
        uint256 _gen, // amount of ETH sent to general vault
        uint256 _keys
    ) private returns (uint256) {
        /* MASKING NOTES
            earnings masks are a tricky thing for people to wrap their minds around.
            the basic thing to understand here.  is were going to have a global
            tracker based on profit per share for each round, that increases in
            relevant proportion to the increase in share supply.
            
            the player will have an additional mask that basically says "based
            on the rounds mask, my shares, and how much i've already withdrawn,
            how much is still owed to me?"
        */

        // calc profit per key & round mask based on this buy:  (dust goes to pot)
        uint256 _ppt = (_gen.mul(1000000000000000000)) / (round_[_rID].keys);
        round_[_rID].mask = _ppt.add(round_[_rID].mask);

        // calculate player earning from their own buy (only based on the keys
        // they just bought).  & update player earnings mask
        uint256 _pearn = (_ppt.mul(_keys)) / (1000000000000000000);
        plyrRnds_[_pID][_rID].mask = (
            ((round_[_rID].mask.mul(_keys)) / (1000000000000000000)).sub(_pearn)
        )
            .add(plyrRnds_[_pID][_rID].mask);

        // calculate & return dust
        return (
            _gen.sub((_ppt.mul(round_[_rID].keys)) / (1000000000000000000))
        );
    }

    /**
     * @dev adds up unmasked earnings, & vault earnings, sets them all to 0
     * @return earnings in wei format
     */
    function withdrawEarnings(uint256 _pID) private returns (uint256) {
        // update gen vault
        updateGenVault(_pID, plyr_[_pID].lrnd);

        // from vaults
        uint256 _earnings =
            (plyr_[_pID].win).add(plyr_[_pID].gen).add(plyr_[_pID].aff);
        if (_earnings > 0) {
            plyr_[_pID].win = 0;
            plyr_[_pID].gen = 0;
            plyr_[_pID].aff = 0;
        }

        return (_earnings);
    }

    /**
     * @dev prepares compression data and fires event for buy or reload tx's
     */
    function endTx(
        uint256 _pID,
        uint256 _eth,
        uint256 _keys,
        F3Ddatasets.EventReturns memory _eventData_
    ) private {
        _eventData_.compressedData =
            _eventData_.compressedData +
            (block.timestamp * 1000000000000000000);
        _eventData_.compressedIDs =
            _eventData_.compressedIDs +
            _pID +
            (rID_ * 10000000000000000000000000000000000000000000000000000);

        emit F3Devents.onEndTx(
            _eventData_.compressedData,
            _eventData_.compressedIDs,
            plyr_[_pID].name,
            msg.sender,
            _eth,
            _keys,
            _eventData_.winnerAddr,
            _eventData_.winnerName,
            _eventData_.amountWon,
            _eventData_.devAmount,
            _eventData_.genAmount,
            _eventData_.potAmount
        );
    }

    // @dev swap from BNB into PIRATE
    function _swap(address _from, uint amount, address _to, address receiver) internal returns (uint) {
        if (_from == _to) return amount;
        // _approveTokenIfNeeded(_from);
        address[] memory path;
        path = new address[](2);
        path[0] = _from;
        path[1] = _to;

        uint[] memory amounts = ROUTER.swapExactETHForTokens{value : amount}(0, path, receiver, block.timestamp);
        return amounts[amounts.length - 1];
    }

    function _approveTokenIfNeeded(address token) internal {
        if (IBEP20(token).allowance(address(this), address(ROUTER)) == 0) {
            IBEP20(token).approve(address(ROUTER), uint(~0));
        }
    }

    //==============================================================================
    //    (~ _  _    _._|_    .
    //    _)(/_(_|_|| | | \/  .
    //====================/=========================================================
    /** upon contract deploy, it will be deactivated.  this is a one time
     * use function that will activate the contract.  we do this so devs
     * have time to set things up on the web end                            **/

    function activate() external payable onlyOwner {
        // only team can activate
        require(msg.sender == DEV, "only team can activate");

        // can only be ran once
        require(activated_ == false, "treasure key bet already activated");

        // activate the contract
        activated_ = true;

        // lets start first round
        rID_ = 1;
        round_[1].strt = block.timestamp;
        round_[1].end = block.timestamp + rndInit_;

        // we seed the pot with a starting balance
        round_[1].pot = msg.value;
    }
}

//==============================================================================
//   __|_ _    __|_ _  .
//  _\ | | |_|(_ | _\  .
//==============================================================================
library F3Ddatasets {
    //compressedData key
    // [76-33][32][31][30][29][28-18][17][16-6][5-3][2][1][0]
    // 0 - new player (bool)
    // 1 - joined round (bool)
    // 2 - new  leader (bool)
    // 6-16 - round end time
    // 17 - winnerTeam
    // 18 - 28 timestamp
    // 30 - 0 = reinvest (round), 1 = buy (round), 2 = buy (ico), 3 = reinvest (ico)
    //compressedIDs key
    // [77-52][51-26][25-0]
    // 0-25 - pID
    // 26-51 - winPID
    // 52-77 - rID
    struct EventReturns {
        uint256 compressedData;
        uint256 compressedIDs;
        address winnerAddr; // winner address
        bytes32 winnerName; // winner name
        uint256 amountWon; // amount won
        uint256 devAmount; // amount distributed to dev
        uint256 genAmount; // amount distributed to gen
        uint256 potAmount; // amount added to pot
    }
    struct Player {
        address addr; // player address
        bytes32 name; // player name
        uint256 win; // winnings vault
        uint256 gen; // general vault
        uint256 aff; // affiliate vault
        uint256 lrnd; // last round played
        uint256 laff; // last affiliate id used
    }
    struct PlayerRounds {
        uint256 eth; // eth player has added to round (used for eth limiter)
        uint256 keys; // keys
        uint256 mask; // player mask
        uint256 ico; // ICO phase investment
    }
    struct Round {
        uint256 plyr; // pID of player in lead
        uint256 end; // time ends/ended
        bool ended; // has round end function been ran
        uint256 strt; // time round started
        uint256 keys; // keys
        uint256 eth; // total eth in
        uint256 pot; // eth to pot (during round) / final amount paid to winner (after round ends)
        uint256 mask; // global mask
        uint256 ico; // total eth sent in during ICO phase
        uint256 icoGen; // total eth for gen during ICO phase
        uint256 icoAvg; // average key price for ICO phase
    }

    struct KeyFee {
        uint256 gen; // % of buy in thats paid to key holders of current round
        uint256 dev; // % of buy in thats paid to develper
        uint256 burn; // % of buy that is used to burn
        uint256 pot; // % of buy that goes to pot
        uint256 pool; // % of buy that goes to pool
        uint256 aff; // % of buy that goes to affliates
    }
    struct PotSplit {
        uint256 win; // % of pot thats paid to winner of current round
        uint256 next; // % of pot thats paid to next round
        uint256 dev; // % of pot for marketing funds
    }
}

//==============================================================================
//  |  _      _ _ | _  .
//  |<(/_\/  (_(_||(_  .
//=======/======================================================================
library F3DKeysCalcLong {
    using SafeMath for *;

    /**
     * @dev calculates number of keys received given X eth
     * @param _curEth current amount of eth in contract
     * @param _newEth eth being spent
     * @return amount of ticket purchased
     */
    function keysRec(uint256 _curEth, uint256 _newEth)
        internal
        pure
        returns (uint256)
    {
        return (keys((_curEth).add(_newEth)).sub(keys(_curEth)));
    }

    /**
     * @dev calculates amount of eth received if you sold X keys
     * @param _curKeys current amount of keys that exist
     * @param _sellKeys amount of keys you wish to sell
     * @return amount of eth received
     */
    function ethRec(uint256 _curKeys, uint256 _sellKeys)
        internal
        pure
        returns (uint256)
    {
        return ((eth(_curKeys)).sub(eth(_curKeys.sub(_sellKeys))));
    }

    /**
     * @dev calculates how many keys would exist with given an amount of eth
     * @param _eth eth "in contract"
     * @return number of keys that would exist
     */
    function keys(uint256 _eth) internal pure returns (uint256) {
        return
            (
                (
                    (
                        (
                            ((_eth).mul(1000000000000000000)).mul(
                                200000000000000000000000000000000
                            )
                        )
                            .add(
                            2500000000000000000000000000000000000000000000000000000000000000
                        )
                    )
                        .sqrt()
                )
                    .sub(50000000000000000000000000000000)
            ) / (100000000000000);
    }

    /**
     * @dev calculates how much eth would be in contract given a number of keys
     * @param _keys number of keys "in contract"
     * @return eth that would exists
     */
    function eth(uint256 _keys) internal pure returns (uint256) {
        return
            (
                (50000000000000).mul(_keys.sq()).add(
                    ((100000000000000).mul(_keys.mul(1000000000000000000))) /
                        (2)
                )
            ) / ((1000000000000000000).sq());
    }
}
