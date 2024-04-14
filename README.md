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

- `InsuranceManager.sol`
- `InsuranceCoverageNFT.sol`
- `YieldManager.sol`
- `AdjusterOperations.sol`

### Insurance Application

Manages most of the user-facing implementation for insurance. Users can apply for insurance, creating a pending application. They also provide some hashed data for personal details that might not be best stored directly on-chain. Then their plan is reviewed by an Adjuster, who gives the application a risk score and either approves or rejects the application. Based on that risk score, a premium is calculated.

The User then has a window (of 7 days) to activate the insurance by providing ERC20 token, paying for some amount of subscription time relative to the premium (which is a per-second cost). The User can also extend their coverage up to some maximum amount of time. Later, they can claim a policy and extract the amount of value for the coverage which they have purchased.

### InsuranceCoverageNFT

When the policy is activated by the User, an NFT is generated to represent their insurance claim. The User is free to burn the token if they want to revoke coverage; otherwise, their coverage is only valid up until the end date defined by the amount of ERC20 token they have provided relative to their premium

#### User Lifecycle

This contract manages the majority of the user-facing executions. It provides an interface that users can directly execute transactions from.

Here is the flow for the lifecycle of a User as they apply for insurance, pay for the plan, and claim a policy.

```mermaid
sequenceDiagram
    autonumber
    actor Adjuster
    participant AdjusterOperationsContract
    actor ApproverAdmin
    actor MasterAdmin

    MasterAdmin ->> AdjusterOperationsContract: set an ApproverAdmin
    AdjusterOperationsContract ->> ApproverAdmin: grant role
    ApproverAdmin ->> AdjusterOperationsContract: set Adjusters
    AdjusterOperationsContract ->> Adjuster: grant role
```

#### Access Controls

There are complex access controls, mostly involving the Adjusters. There is a Master Admin defined in the AdjusterOperations contract, with the power of granting Approver roles. Those Approvers have the power to provision Adjusters. There is a requirement of 1 Approver and 3 Adjusters for normal operations to commence. Separation of access controls here provides a more secure way of managing.

### Insurance Adjusters Lifecycle

Here is the flow for the lifecycle of Insurance Adjusters as they get approved.

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
