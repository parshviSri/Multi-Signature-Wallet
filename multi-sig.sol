// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract MultiSigWallet{
    // user can deposit a transaction
    event Deposit(address indexed sender, uint amount);

    // Once thte transaction is completed it needs to be submited for approval
     event Submit( uint indexed txId);

    // transaction needs to be approved by Owners
    event Approve(address indexed owner, uint indexed txId);

    //Once Approved Owner can also revoke the transaction
    event Revoke(address indexed owner, uint indexed txId);

    //If nothing is wrong then it will be executed 
    event Execute(uint indexed txId);

    // Transaction struct
    struct Transaction{
        address to; // reciever address
        uint amount;// amount transfered
        bytes data;// data send to sender
        bool executed; // if the transaction is executed
    }

    // List of all owners Address
    address [] owners;

    mapping(address => bool) public isOwner;

    // no of approvals required for any transaction to be executed.
    uint public noOfApprovals;

    Transaction[] public transactions;

    // to check if transaction id is approved by the a particular owner or not
    mapping(uint => mapping(address => bool)) public transactionApproved;

    //modifier to check if only owner can submit the approval request
    modifier onlyOwner(){
        require(isOwner[msg.sender],"You cann't make this request you are not a owner");
        _;
    }

    //modifier to check transaction Id
    modifier txIDExists( uint _txId){
        require(_txId<transactions.length,"Transaction already exist");
        _;
    }
    // modifier to check if the transaction is already approved
    modifier notApproved(uint _txId){
        require(!transactionApproved[_txId][msg.sender],"Already Approved");
        _;
    }
    // modifier to check if transaction is already executed
    modifier notExecuted(uint _txId){
        require(!transactions[_txId].executed);
        _;
    }

    // to intiate the owner list and required no of approvals
    constructor(address[] memory _owners, uint _noOfApprovals) {
        // we need to check if there is atleast one owner
        require(_owners.length>0,"Atleast one woner is required");
        // we need to check if no of approval should be between the length of the owner list
        require(_noOfApprovals>0 && noOfApprovals<= _owners.length,"Invalid no of Approvals");
        // push the data to the array
        for(uint i; i< _owners.length; i++) {
            address owner= _owners[i];
            // we need to check the address of owner exist
            require(owner != address(0),"Address of owner is invalid");
            // check if the owner is already present
            require(!isOwner[owner], "Owner already exist");
            isOwner[owner] = true;
            owners.push(owner);
        }
        noOfApprovals = _noOfApprovals;
    }

    // recieving the ether
    receive() external payable{
        emit Deposit(msg.sender, msg.value);
    }

    // submiting the request for owners to approve by adding data to transaction can be done by owner only
    function submitTransaction( address _to, uint _amount, bytes calldata _data)  external onlyOwner{
        transactions.push(Transaction({
            to: _to,
            amount : _amount,
            data : _data,
            executed: false
        }));
        // emit the submit event
        emit Submit(transactions.length-1);


    }
// function to approve the transaction
// Only owner should be able to approve it
// tax Id should exists
// should not be already approved
// should not be already be executed
    function approve( uint _txId) external onlyOwner txIDExists(_txId) notApproved(_txId) notExecuted(_txId){
        transactionApproved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);

    }
    // function to check if the number of approval is passing for a transaction
    function _getNoOfApprovalChecked(uint _txId) private view returns(uint count){
        for(uint i; i< owners.length;i++){
            if(transactionApproved[_txId][owners[i]]){
                count+=1;
            }
        }
    }
    // function to execute the the transaction
    function executeTransaction(uint _txId) external txIDExists(_txId) notExecuted(_txId){
        // check if no of Approvals criteria is met
        require(_getNoOfApprovalChecked(_txId) == noOfApprovals);
        // create a storage to store transaction add it to block chain
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        // send amount of ether we want to send to the block chain using call function
        (bool success, ) = transaction.to.call{value: transaction.amount}(
            transaction.data
        );
        require(success,"Failed transaction");
        emit Execute(_txId);
    }
    // function to revoke the  before executed
    function revokeTransaction(uint _txId) external onlyOwner txIDExists(_txId) notExecuted(_txId){
        // check if it is already approved
        require(transactionApproved[_txId][msg.sender], "Not approved");
        transactionApproved[_txId][msg.sender] = false;
        emit Revoke(msg.sender,_txId);

    }
}
