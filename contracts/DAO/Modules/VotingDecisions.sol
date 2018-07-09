pragma solidity 0.4.24;

import '../../../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol';
import "../DAOLib.sol";
import "../../Token/TokenInterface.sol";
import "../CrowdsaleDAOFields.sol";
import "../API/IService.sol";

contract VotingDecisions is CrowdsaleDAOFields {

    /*
    * @dev Transfers withdrawal sum in ether or DXC tokens to the whitelisted address. Calls from Withdrawal proposal
    * @param _address Whitelisted address
    * @param _withdrawalSum Amount of ether/DXC to be sent
    * @param _dxc Should withdrawal be in DXC tokens
    */
    function withdrawal(address _address, uint _withdrawalSum, bool _dxc) external notInRefundableState onlyVoting {
        lastWithdrawalTimestamp = block.timestamp;
        _dxc ? DXC.transfer(_address, _withdrawalSum) : _address.transfer(_withdrawalSum);
    }

    /*
    * @dev Change DAO's mode to `refundable`. Can be called by any tokenholder
    */
    function makeRefundableByUser() external {
        require(lastWithdrawalTimestamp == 0 && block.timestamp >= created_at + withdrawalPeriod
        || lastWithdrawalTimestamp != 0 && block.timestamp >= lastWithdrawalTimestamp + withdrawalPeriod);
        makeRefundable();
    }

    /*
    * @dev Change DAO's mode to `refundable`. Calls from Refund proposal
    */
    function makeRefundableByVotingDecision() external onlyVoting {
        makeRefundable();
    }

    /*
    * @dev Change DAO's mode to `refundable`. Calls from this contract `makeRefundableByUser` or `makeRefundableByVotingDecision` functions
    */
    function makeRefundable() private notInRefundableState {
        refundable = true;
        newEtherRate = SafeMath.mul(this.balance * etherRate, multiplier) / tokensMintedByEther;
        newDXCRate = tokensMintedByDXC != 0 ? SafeMath.mul((DXC.balanceOf(this) - initialCapital) * DXCRate, multiplier) / tokensMintedByDXC : 0;
    }

    /*
    * @dev Make tokens of passed address non-transferable for passed period
    * @param _address Address of tokenholder
    * @param _duration Hold's duration in seconds
    */
    function holdTokens(address _address, uint _duration) external onlyVoting {
        token.hold(_address, _duration);
    }

    function connectService(address _service) external onlyVoting validInitialCapital(_service) {
        uint price = IService(_service).price();
        initialCapital -= price;
        DXC.contributeTo(_service, price);
        modules[_service] = true;
    }

    /*
    * @dev Throws if called not by any voting contract
    */
    modifier onlyVoting() {
        require(votings[msg.sender] != 0x0);
        _;
    }

    /*
    * @dev Throws if DAO is in refundable state
    */
    modifier notInRefundableState {
        require(!refundable && !refundableSoftCap);
        _;
    }

    modifier validInitialCapital(address _service) {
        require(IService(_service).price() <= initialCapital, "Not enough funds to connect module");
        _;
    }
}
