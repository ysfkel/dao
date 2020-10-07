pragma solidity ^0.5.2;

contract DAO {
    /**
    DAO contract:
    1. Collects investors money (ether)
    2. Keep track of investor contributions with shares 
    3. Allow investors to transfer shares 
    4. allow investent proposals to be created 
    5. execute successful investment proposals (i.e send money)
     */

     struct Proposal {
         uint id;
         string name;
         uint amount;
         //the ether will be sent to another smart contract which represent the investment 
         address payable recepient;
         uint votes;
         uint end; //timestamp
         bool isExecuted;
     }

     //tracks investors
     mapping(address => bool) public investors;
     //tracks investors investments allocated to each investor 
     mapping(address => uint) public shares;
     mapping(uint => Proposal) public proposals;
     //check if user already voted for specified proposal
     mapping(address => mapping(uint => bool)) public votes;
     uint public totalShares;
     uint public availableFunds;
     uint public contributionEnd;
     uint public nextProposalId;
     uint public voteTime; // each proposal has a voting time
     // quorum minimum require votes to execute a proposal
     // in percent , eg 50 percent of votes
     uint public quorum;
     address public admin;
 
     constructor (
         uint contributionTime,
         uint _voteTime,
         uint _quorum
         ) public {
        require(_quorum > 0 && _quorum < 100, "quorum must be between 0 and 100 ");
         contributionEnd = now + contributionTime;
         voteTime = _voteTime;
         quorum = _quorum;
         admin = msg.sender;
     }

     function contribute() payable external {
          
        require(now < contributionEnd, "cannot contribute after contribution end");

         investors[msg.sender] = true; 
         //allocate investor 
         //we will use 1 wei = 1 share 
         shares[msg.sender] += msg.value;    
         totalShares += msg.value;
         availableFunds += msg.value;
     }

     function redeemShare(uint amount) external{

         require(shares[msg.sender] >= amount, "the investor does not own enough shares");
         //check if we have enough liquidity (available funds) to pay the investor 
         require(availableFunds >= amount, "not enough available funds");
         //decrement investor shares 
         shares[msg.sender] -= amount;
         //decrement available funds
         availableFunds -= amount;
         //send amount to investor
         /**
         this assumes that 1 share = 1 wei at the time of redemption of share 
         which may not be the case . because the value of an investment might have increased to 2 wei 
         or decrised, to fix this we need an oracle smart contract which is beyon current scope
          */
         msg.sender.transfer(amount);

     }


    /**
       to transfer shares between two investors
       useful in the context of a transaction between 2 investors 
       that happen outside the smart contract.
       eg 
       Investor A wants to sell 100 shares to investor B
       Investor A will place a sell order in an exchange outside the smart contract 
       from a centralized or decentralized exchange 
       Investor B sees the sell order and places buy order for 100 ether eg
       Investor B sends the ether to the exchange 
       exchange triggers transfer share funcion 
     */ 
    function transferShare(uint amount, address recepient) external {
        
         require(shares[msg.sender] >= amount, "the investor does not own enough shares");
       
        shares[msg.sender] -= amount; 
        shares[recepient] += amount;
        investors[recepient] = true;
    }
    
    /**
      4. Allow investors to transfer shares 
      one investor creates a proposal, other investors vote 
      at the end of the vote the investment proposal can be executed (point 4)
     */ 
     function createProposal(
         string calldata name,
         uint amount,
         address payable recepient) 
         external  
         onlyInvestors()
         {

             //check that proposal amout does not exceed availableFunds
             require(availableFunds >= amount , "proposal amount is too big");

            proposals[nextProposalId] = Proposal(
                nextProposalId,
                name, 
                amount,
                recepient,
                0, //initialze votes to 0
                now + voteTime,
                false //isExecuted
            );
            availableFunds -= amount; 
            nextProposalId ++;
    }


    function vote(uint proposalId)  external onlyInvestors() {
           require(votes[msg.sender][proposalId] == false, "cannot vote more than once");
           //create storage pointer 
           Proposal storage proposal = proposals[proposalId];
           require(now < proposal.end, "cannot vote after voting deadline");
    
           votes[msg.sender][proposalId] = true; 
           //cannot increment by one because different investors have different 
           //voting weight , so we will instead add the number of shares of an investor
           proposal.votes += shares[msg.sender];
    }

    function executeProposal(uint proposalId) external onlyAdmin() {

        Proposal storage proposal = proposals[proposalId];
        require(now >= proposal.end, "cannot execute proposal before end date");
        require(proposal.isExecuted == false,"cannot execute an active proposal");
        require((proposal.votes / totalShares) * 100 >= quorum, "cannot execute proposal with votes below quorum"); //check if we have enough votes
        
        _transferEther(proposal.amount, proposal.recepient);

    }

     //can only be called inside the smart contract
    function _transferEther (uint amount, address payable to) internal {
         require(amount <= availableFunds, "not enough funds available");
         availableFunds -= amount;
         to.transfer(amount);
    }

    function withdrawEther(uint amount, address payable to) external onlyAdmin() {
           _transferEther(amount, to);
    }
     
    modifier onlyInvestors {
        require(investors[msg.sender] == true, "only investors");
        _;
    }

    //fallback function 
    /**
      used to receive ether that is sent from another smart contract
      such as the recipient smart contract to send back ether 
     */
    function() payable external {
         availableFunds += msg.value;
    }

    modifier onlyAdmin {
        require(msg.sender == admin, "only admin");
        _;
    }

}