// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Voltara Node Army Monolith v1.1 — Boosted, ETH Mainnet Only
/// @notice Registry + tiers + merit + boost engine. All ETH auto-forwarded.
contract NodeArmyMonolithEthMainnet {
    // --- Types ---

    enum Tier {
        NONE,
        SCOUT,
        OPERATOR,
        OVERSEER
    }

    /// @dev Boost IDs (1..5)
    /// 1 = SPEED
    /// 2 = POWER
    /// 3 = SHIELD
    /// 4 = LUCK
    /// 5 = VISION

    struct Node {
        bool active;
        Tier tier;
        uint256 merit;
        uint256 joinedAt;
    }

    // --- Storage ---

    address public owner;
    address public treasury;
    address public founder;

    uint16 public treasuryBps; // e.g. 7000 = 70%

    uint256 public registerFee;
    uint256 public upgradeFee;
    uint256 public actionFee;
    uint256 public boostFee;

    uint8 public constant MAX_BOOST_LEVEL = 5;
    uint16 public constant BOOST_BONUS_PER_LEVEL_BPS = 1000; // +10% per level

    mapping(address => Node) public nodes;
    mapping(address => mapping(uint8 => uint8)) public boosts; // node => boostId => level

    uint256 public totalNodes;

    // --- Events ---

    event NodeRegistered(address indexed node, Tier tier, uint256 feePaid);
    event NodeUpgraded(address indexed node, Tier newTier, uint256 feePaid);
    event NodeAction(address indexed node, uint256 baseMerit, uint256 finalMerit, uint256 feePaid);
    event BoostPurchased(address indexed node, uint8 boostId, uint8 newLevel, uint256 feePaid);
    event MeritAdjusted(address indexed node, uint256 newMerit);

    event ParamsUpdated(
        uint256 registerFee,
        uint256 upgradeFee,
        uint256 actionFee,
        uint256 boostFee,
        uint16 treasuryBps
    );

    event Payout(address indexed to, uint256 amount);
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);
    event PayoutAddressesUpdated(address treasury, address founder);

    // --- Modifiers ---

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyActiveNode() {
        require(nodes[msg.sender].active, "Not a node");
        _;
    }

    // --- Constructor ---

    constructor(
        address _treasury,
        address _founder,
        uint16 _treasuryBps,
        uint256 _registerFee,
        uint256 _upgradeFee,
        uint256 _actionFee,
        uint256 _boostFee
    ) {
        require(_treasury != address(0), "treasury zero");
        require(_founder != address(0), "founder zero");
        require(_treasuryBps <= 10_000, "bps > 100%");

        owner = msg.sender;
        treasury = _treasury;
        founder = _founder;

        treasuryBps = _treasuryBps;
        registerFee = _registerFee;
        upgradeFee = _upgradeFee;
        actionFee = _actionFee;
        boostFee = _boostFee;
    }

    // --- Core flows ---

    function registerNode() external payable {
        require(!nodes[msg.sender].active, "already node");
        require(msg.value == registerFee, "fee mismatch");

        nodes[msg.sender] = Node({
            active: true,
            tier: Tier.SCOUT,
            merit: 0,
            joinedAt: block.timestamp
        });

        totalNodes += 1;
        _splitAndSend(msg.value);

        emit NodeRegistered(msg.sender, Tier.SCOUT, msg.value);
    }

    function upgradeTier() external payable onlyActiveNode {
        Node storage n = nodes[msg.sender];
        require(n.tier != Tier.OVERSEER, "max tier");
        require(msg.value == upgradeFee, "fee mismatch");

        if (n.tier == Tier.SCOUT) {
            n.tier = Tier.OPERATOR;
        } else if (n.tier == Tier.OPERATOR) {
            n.tier = Tier.OVERSEER;
        }

        _splitAndSend(msg.value);
        emit NodeUpgraded(msg.sender, n.tier, msg.value);
    }

    /// @notice Perform a monetized action; merit is boosted by owned boosts.
    function nodeAction(uint256 baseMerit) external payable onlyActiveNode {
        require(msg.value == actionFee, "fee mismatch");
        require(baseMerit > 0, "no merit");

        uint256 bonusBps = getBoostBonusBps(msg.sender);
        uint256 finalMerit =
            (baseMerit * (10_000 + bonusBps)) / 10_000;

        nodes[msg.sender].merit += finalMerit;

        _splitAndSend(msg.value);

        emit NodeAction(msg.sender, baseMerit, finalMerit, msg.value);
        emit MeritAdjusted(msg.sender, nodes[msg.sender].merit);
    }

    // --- Boost system ---

    function buyBoost(uint8 boostId) external payable onlyActiveNode {
        require(boostId >= 1 && boostId <= 5, "invalid boost");
        require(msg.value == boostFee, "fee mismatch");

        uint8 level = boosts[msg.sender][boostId];
        require(level < MAX_BOOST_LEVEL, "max boost");

        boosts[msg.sender][boostId] = level + 1;

        _splitAndSend(msg.value);

        emit BoostPurchased(msg.sender, boostId, level + 1, msg.value);
    }

    function getBoostBonusBps(address node) public view returns (uint256 totalBps) {
        for (uint8 i = 1; i <= 5; i++) {
            totalBps += boosts[node][i] * BOOST_BONUS_PER_LEVEL_BPS;
        }
    }

    // --- Admin ---

    function adjustMerit(address nodeAddr, int256 delta) external onlyOwner {
        Node storage n = nodes[nodeAddr];
        require(n.active, "not active");

        if (delta >= 0) {
            n.merit += uint256(delta);
        } else {
            uint256 abs = uint256(-delta);
            n.merit = abs >= n.merit ? 0 : n.merit - abs;
        }

        emit MeritAdjusted(nodeAddr, n.merit);
    }

    function setParams(
        uint256 _registerFee,
        uint256 _upgradeFee,
        uint256 _actionFee,
        uint256 _boostFee,
        uint16 _treasuryBps
    ) external onlyOwner {
        require(_treasuryBps <= 10_000, "bps > 100%");
        registerFee = _registerFee;
        upgradeFee = _upgradeFee;
        actionFee = _actionFee;
        boostFee = _boostFee;
        treasuryBps = _treasuryBps;

        emit ParamsUpdated(_registerFee, _upgradeFee, _actionFee, _boostFee, _treasuryBps);
    }

    function setPayoutAddresses(address _treasury, address _founder) external onlyOwner {
        require(_treasury != address(0), "treasury zero");
        require(_founder != address(0), "founder zero");
        treasury = _treasury;
        founder = _founder;

        emit PayoutAddressesUpdated(_treasury, _founder);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        emit OwnerChanged(owner, newOwner);
        owner = newOwner;
    }

    // --- Internal ETH split ---

    function _splitAndSend(uint256 amount) internal {
        uint256 toTreasury = (amount * treasuryBps) / 10_000;
        uint256 toFounder = amount - toTreasury;

        if (toTreasury > 0) {
            (bool okT, ) = treasury.call{value: toTreasury}("");
            require(okT, "treasury failed");
            emit Payout(treasury, toTreasury);
        }

        if (toFounder > 0) {
            (bool okF, ) = founder.call{value: toFounder}("");
            require(okF, "founder failed");
            emit Payout(founder, toFounder);
        }
    }

    // --- Safety ---

    receive() external payable {
        revert("use functions");
    }

    fallback() external payable {
        revert("invalid");
    }
}