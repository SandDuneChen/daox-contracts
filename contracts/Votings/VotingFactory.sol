pragma solidity ^0.4.0;

import "./VotingFactoryInterface.sol";
import "./Regular.sol";
import "./Withdrawal.sol";
import "./Refund.sol";
import "./Module.sol";
import "../DAO/DAOFactoryInterface.sol";
import "../DAO/IDAO.sol";

contract VotingFactory is VotingFactoryInterface {
    address baseVoting;
    DAOFactoryInterface public daoFactory;

    function VotingFactory(address _baseVoting) {
        baseVoting = _baseVoting;
    }

    function createRegular(address _creator, string _name, string _description, uint _duration, bytes32[] _options)
        external
        onlyDAO
        onlyParticipant(_creator)
        returns (address)
    {
        return new Regular(baseVoting, msg.sender, _name, _description, _duration, _options);
    }

    function createWithdrawal(address _creator, string _name, string _description, uint _duration, uint _sum, address withdrawalWallet, bool _dxc)
        external
        onlyTeamMember(_creator)
        onlyDAO
        onlyWhiteList(withdrawalWallet)
        returns (address)
    {
        return new Withdrawal(baseVoting, msg.sender, _name, _description, _duration, _sum, withdrawalWallet, _dxc);
    }

    function createRefund(address _creator, string _name, string _description, uint _duration) external onlyDAO onlyParticipant(_creator) returns (address) {
        return new Refund(baseVoting, msg.sender, _name, _description, _duration);
    }

    function createModule(address _creator, string _name, string _description, uint _duration, uint _module, address _newAddress)
        external
        onlyDAO
        onlyParticipant(_creator)
        returns (address)
    {
        return new Module(baseVoting, msg.sender, _name, _description, _duration, _module, _newAddress);
    }

    function setDaoFactory(address _dao) external {
        require(address(daoFactory) == 0x0 && _dao != 0x0);
        daoFactory = DAOFactoryInterface(_dao);
    }

    modifier onlyDAO() {
        require(daoFactory.exists(msg.sender));
        _;
    }

    modifier onlyParticipant(address creator) {
        require(IDAO(msg.sender).isParticipant(creator));
        _;
    }

    modifier onlyTeamMember(address creator) {
        require(IDAO(msg.sender).teamMap(creator));
        _;
    }

    modifier onlyWhiteList(address creator) {
        require(IDAO(msg.sender).whiteList(creator));
        _;
    }
}
