# Stakepool Contract

A Clarity smart contract implementing a reputation-based staking protocol on the Stacks blockchain.

## Overview

The Stakepool contract allows users to stake STX tokens and build reputation scores within a decentralized pool. It includes administrative controls, governance integration, and reputation decay mechanisms.

## Features

- **Staking**: Users can stake STX tokens to build reputation
- **Unstaking**: Request to unstake with a configurable unlock delay
- **Reputation System**: Earn reputation based on stake amount and duration
- **Governance Integration**: Optional governance contract for protocol decisions
- **Admin Controls**: Administrative functions for protocol configuration
- **Reputation Adjustments**: Adjust user reputation scores for rewards or penalties
- **Slashing**: Remove stake from users for policy violations

## Key Functions

### Public Functions

- `stake-amount(amount)` - Deposit STX to stake
- `stake-confirm(amount)` - Confirm staking
- `request-unstake(amount)` - Request to unstake tokens
- `withdraw(unlock-id)` - Withdraw unstaked tokens after unlock period
- `adjust-reputation(user, delta)` - Adjust user reputation (admin only)
- `slash(user, amount, reason)` - Slash user stake (admin only)
- `set-governance(gov)` - Set governance contract address (admin only)
- `set-stake-multiplier(m)` - Configure reputation multiplier (admin only)

### Read-Only Functions

- `get-stake(user)` - Get user's current stake
- `get-total-staked()` - Get total staked in pool
- `get-reputation(user)` - Get user's reputation score
- `get-unlock(id)` - Get unlock request details

## Configuration

- `stake-multiplier` - Reputation multiplier per staked STX
- `base-rep` - Base reputation score
- `decay-per-day` - Daily reputation decay rate
- `unlock-delay` - Blocks to wait before withdrawing unstaked tokens (default: 7 days)

## Error Codes

- `ERR-UNAUTHORIZED` (100) - Unauthorized action
- `ERR-NOT-ENOUGH-STX` (101) - Insufficient stake balance
- `ERR-NO-UNLOCK` (102) - Unlock request not found
- `ERR-ALREADY-GOV` (103) - Governance already set
- `ERR-INVALID-ARG` (104) - Invalid argument

er at initialization
