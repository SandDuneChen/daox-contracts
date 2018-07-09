pragma solidity ^0.4.0;

import "./DAOFactoryInterface.sol";
import "./DAODeployer.sol";
import "../Common.sol";
import "../Token/TokenInterface.sol";

interface IDAOModules {
    function setStateModule(address _stateModule) external;
    function setPaymentModule(address _paymentModule) external;
    function setVotingDecisionModule(address _votingDecisionModule) external;
    function setCrowdsaleModule(address _crowdsaleModule) external;
    function setProxyAPI(address _proxyAPI) external;
    function setApiSettersModule(address _allowedSetters) external;
}

contract CrowdsaleDAOFactory is DAOFactoryInterface {
    event CrowdsaleDAOCreated(
        address _address,
        string _name
    );

    address public serviceContractAddress;
    address public votingFactory;
    address public serviceVotingFactory;
    address public DXC;
    mapping(address => uint) DXCDeposit;
    // DAOs created by factory
    mapping(address => string) DAOs;
    // Functional modules which will be used by DAOs to delegate calls
    address[6] modules;

    function CrowdsaleDAOFactory(address _serviceContract, address _votingFactory, address _serviceVotingFactory, address _DXC, address[6] _modules) {
        require(_serviceContract != 0x0 && _votingFactory != 0x0 && _serviceVotingFactory != 0x0 && _DXC != 0x0);
        serviceContractAddress = _serviceContract;
        DXC = _DXC;
        votingFactory = _votingFactory;
        serviceVotingFactory = _serviceVotingFactory;
        modules = _modules;

        require(votingFactory.call(bytes4(keccak256("setDaoFactory(address)")), this));
        require(serviceVotingFactory.call(bytes4(keccak256("setDaoFactory(address)")), this));
        require(serviceContractAddress.call(bytes4(keccak256("setDaoFactory(address)")), this));
    }

    /*
    * @dev Checks if provided address is an address of some DAO contract created by this factory
    * @param _address Address of contract
    * @return boolean indicating whether the contract was created by this factory or not
    */
    function exists(address _address) external constant returns (bool) {
        return keccak256(DAOs[_address]) != keccak256("");
    }

    /*
    * @dev Receives info about address which sent DXC tokens to current contract and about amount of sent tokens from
    *       DXC token contract and then saves this information to DXCDeposit mapping
    * @param _from Address which sent DXC tokens
    * @param _amount Amount of tokens which were sent
    */
    function handleDXCPayment(address _from, uint _dxcAmount) external onlyDXC {
        require(_dxcAmount >= 10**18, "Amount of DXC for initial deposit must be equal or greater than 1 DXC");

        DXCDeposit[_from] += _dxcAmount;
    }

    /*
    * @dev Creates new CrowdsaleDAO contract, provides it with addresses of modules, transfers ownership to tx sender
    *      and saves address of created contract to DAOs mapping
    * @param _name Name of the DAO
    * @param _name Description for the DAO
    * @param _initialCapital initial capital for DAO that will be created
    */
    function createCrowdsaleDAO(string _name, string _description, uint _initialCapital) public correctInitialCapital(_initialCapital) enoughDXC(_initialCapital) {
        address dao = DAODeployer.deployCrowdsaleDAO(_name, _description, serviceContractAddress, votingFactory, serviceVotingFactory, DXC, _initialCapital);
        DXCDeposit[msg.sender] -= _initialCapital;
        TokenInterface(DXC).transfer(dao, _initialCapital);

        IDAOModules(dao).setStateModule(modules[0]);
        IDAOModules(dao).setPaymentModule(modules[1]);
        IDAOModules(dao).setVotingDecisionModule(modules[2]);
        IDAOModules(dao).setCrowdsaleModule(modules[3]);
        IDAOModules(dao).setProxyAPI(modules[4]);
        IDAOModules(dao).setApiSettersModule(modules[5]);
        DAODeployer.transferOwnership(dao, msg.sender);

        DAOs[dao] = _name;
        CrowdsaleDAOCreated(dao, _name);
    }

    modifier onlyDXC() {
        require(msg.sender == address(DXC), "Method can be called only from DXC contract");
        _;
    }

    modifier correctInitialCapital(uint value) {
        require(value >= 10**18, "Initial capital should be equal at least 1 DXC");
        _;
    }

    modifier enoughDXC(uint value) {
        require(value <= TokenInterface(DXC).balanceOf(this), "Not enough DXC tokens were transferred for such initial capital");
        require(DXCDeposit[msg.sender] >= value, "Not enough DXC were transferred by your address");
        _;
    }
}