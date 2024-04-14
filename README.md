# On-Chain Car Insurance

## Introduction

This project aims to implement an on-chain version of car insurance. Users can apply for insurance policies, which are approved or denied by admin insurance adjusters, who also determine risk factors for the given user in order to calculate the premium that must be paid to maintain coverage.

Users can then activate their policy by providing payment in the form of ERC20 token, which is pooled together and supplied to a lending pool with Aave integration in order to generate yield. When a policy is activated, the user will receive an ERC721 NFT to signify their coverage.

Later on, users can make a claim on their insurance policy in order to get a payout, or extend existing coverage within a certain time frame. There are a multitude of admin roles that govern the process, in particular around approving insurance applications.

## Getting Started

### Setup

This project was built with hardhat-foundry, with Solidity-based Foundry tests.

### Testing

To run the tests and view code coverage:

```
$ forge coverage
```

### Deployment

Fill in `.env.example` with required values.

`MASTER_ADMIN` is the admin for the `AdjusterOperations.sol` contract, `PAYMENT_TOKEN_ADDRESS` is the address of the accepted ERC20 token for payment, and `POOL_ADDRESS` is the address of the Aave lending pool for accruing yield.

The values in `.env.example` are for Sepolia so `RPC_URL` should also correspond to Sepolia.

To simulate a deployment:

```
$ forge script script/DeploymentSuite.s.sol --rpc-url $RPC_URL
```

## Architecture

There are primarily 4 smart contracts that govern the functionality:

### `InsuranceManager.sol`

This contract manages the majority of the user-facing executions. It provides an interface that users can directly execute transactions from.

```
sequenceDiagram
    autonumber
    actor User
    participant InsuranceManagerContract
    participant YieldManagerContract
    participant InsuranceCoverageNFTContract
    actor InsuranceAdjuster

    User ->> InsuranceManagerContract: submitApplication with value to ensure / car details
    InsuranceAdjuster ->> InsuranceManagerContract: reviewApplication to approve/reject and determine risk
    InsuranceManagerContract ->> InsuranceManagerContract: calculate premium
    User ->> InsuranceManagerContract: activatePolicy
    User ->> YieldManagerContract: ERC20 Payment Tokens are used to generate yield
    InsuranceManagerContract ->> InsuranceCoverageNFTContract: mint NFT
    InsuranceCoverageNFTContract ->> User: receive NFT
    User ->> InsuranceManagerContract: claimPolicy to get a payout
    YieldManagerContract ->> User: Returns withdrawn tokens for insured value
```

## Further Improvements

- more optimized yield
- governance features for inspectors approval
- more complex risk logic for calculating premiums
- upgradability
- - improved risk analysis logic
- more payment token options
- more off-chain incorporation of user car details, perhaps hashed
- get tokens out

## Appendix
