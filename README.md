# sBTC Liquid Staking Protocol

A decentralized liquid staking solution for sBTC on the Stacks blockchain that allows users to stake their sBTC while maintaining liquidity through tradeable liquid staking tokens (lstBTC).

## Overview

The sBTC Liquid Staking Protocol enables users to participate in Bitcoin stacking rewards without locking up their assets. Users deposit sBTC and receive lstBTC tokens that represent their staked position plus accumulated rewards. The lstBTC tokens can be traded, used in DeFi protocols, or redeemed for the underlying sBTC at any time.

## Key Features

- **Liquid Staking**: Stake sBTC and receive tradeable lstBTC tokens
- **Automatic Rewards**: Exchange rate increases as stacking rewards are accumulated
- **Instant Liquidity**: Unstake at any time without waiting periods
- **SIP-010 Compliance**: lstBTC tokens follow the standard fungible token interface
- **Protocol Governance**: Owner-controlled parameters and emergency functions
- **Transparent Pricing**: Real-time exchange rate calculations

## Architecture

### System Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Users       │    │   Protocol      │    │  Stacking Pool  │
│                 │    │   Contract      │    │                 │
│ - Stake sBTC    │◄──►│ - Mint lstBTC   │◄──►│ - Accumulate    │
│ - Hold lstBTC   │    │ - Burn lstBTC   │    │   Rewards       │
│ - Unstake       │    │ - Track Rates   │    │ - Update Rates  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Contract Architecture

The protocol consists of several key components:

1. **Token Management**: SIP-010 compliant lstBTC fungible token
2. **Staking Engine**: Core logic for stake/unstake operations
3. **Rate Calculator**: Dynamic exchange rate based on accumulated rewards
4. **Admin Controls**: Owner functions for protocol management
5. **Emergency Systems**: Circuit breakers and pause mechanisms

## Data Flow

### Staking Flow

```
User sBTC → Protocol Contract → Mint lstBTC → User Wallet
     ↓
Update Global State (total staked, supply, exchange rate)
```

### Unstaking Flow  

```
User lstBTC → Protocol Contract → Burn lstBTC → Return sBTC
     ↓
Update Global State (reduce totals, maintain exchange rate)
```

### Rewards Integration

```
Stacking Rewards → Admin adds rewards → Exchange Rate ↑ → lstBTC value ↑
```

## Smart Contract Functions

### Core User Functions

#### `stake-sbtc (amount uint)`

Stakes sBTC tokens and mints corresponding lstBTC tokens based on current exchange rate.

**Parameters:**

- `amount`: Amount of sBTC to stake (minimum 0.01 sBTC)

**Returns:** Amount of lstBTC tokens minted

#### `unstake-lstbtc (lstbtc-amount uint)`

Burns lstBTC tokens and returns corresponding sBTC based on current exchange rate.

**Parameters:**

- `lstbtc-amount`: Amount of lstBTC tokens to burn

**Returns:** Amount of sBTC returned

### SIP-010 Token Interface

The contract implements the complete SIP-010 standard:

- `transfer`: Transfer lstBTC tokens between addresses
- `get-balance`: Get lstBTC balance for an address  
- `get-total-supply`: Get total lstBTC supply
- `get-name`: Returns "Liquid Staked Bitcoin"
- `get-symbol`: Returns "lstBTC"
- `get-decimals`: Returns 8 (matching Bitcoin precision)

### Read-Only Functions

#### `get-exchange-rate`

Returns current exchange rate (lstBTC to sBTC ratio, scaled by 1M).

#### `get-pool-stats`

Returns comprehensive pool statistics:

```clarity
{
  total-sbtc-staked: uint,
  total-lstbtc-supply: uint,
  exchange-rate: uint,
  rewards-accumulated: uint,
  pool-active: bool
}
```

#### `get-user-info (user principal)`

Returns user-specific information:

```clarity
{
  original-stake: uint,
  lstbtc-balance: uint,
  current-sbtc-value: uint
}
```

#### `calculate-stake-output (sbtc-amount uint)`

Calculates lstBTC tokens that would be minted for given sBTC amount.

#### `calculate-unstake-output (lstbtc-amount uint)`

Calculates sBTC that would be returned for given lstBTC amount.

### Administrative Functions

#### `add-rewards (reward-amount uint)`

Adds stacking rewards to the pool, automatically updating the exchange rate.

**Access:** Contract owner only

#### `set-protocol-fee (new-fee uint)`

Sets protocol fee (maximum 10%, scaled by 10000).

**Access:** Contract owner only

#### `set-min-stake-amount (new-min uint)`

Updates minimum staking amount requirement.

**Access:** Contract owner only

#### `toggle-pool (active bool)`

Enables or disables staking/unstaking operations.

**Access:** Contract owner only

#### `emergency-pause`

Immediately pauses all pool operations.

**Access:** Contract owner only

## Exchange Rate Mechanism

The exchange rate determines the value relationship between lstBTC and sBTC:

- **Initial Rate**: 1:1 (1 lstBTC = 1 sBTC)
- **Rate Updates**: When rewards are added, rate increases proportionally
- **Formula**: `new_rate = (total_sbtc_staked + rewards) / total_lstbtc_supply`
- **Scaling**: Rates are scaled by 1,000,000 for precision

### Example

- 100 sBTC staked → 100 lstBTC minted (1:1 rate)
- 10 sBTC rewards added → rate becomes 1.1:1
- 100 lstBTC now worth 110 sBTC

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `err-owner-only` | Function restricted to contract owner |
| u101 | `err-insufficient-balance` | User has insufficient lstBTC balance |
| u102 | `err-insufficient-liquidity` | Protocol lacks sufficient sBTC liquidity |
| u103 | `err-invalid-amount` | Amount doesn't meet requirements |
| u104 | `err-slippage-exceeded` | Transaction would exceed slippage tolerance |
| u105 | `err-pool-not-active` | Pool operations are currently paused |

## Security Considerations

### Access Control

- Critical functions restricted to contract owner
- Emergency pause functionality for crisis response
- Parameter bounds checking (e.g., maximum fees)

### Economic Security

- Minimum staking amounts prevent dust attacks
- Exchange rate precision prevents rounding exploits
- Liquidity checks ensure protocol solvency

### Operational Security

- Pool can be paused during emergencies
- Comprehensive event logging for monitoring
- Input validation on all public functions

## Integration Guide

### For DeFi Protocols

lstBTC tokens are fully SIP-010 compliant and can be integrated like any fungible token:

```clarity
;; Transfer lstBTC
(contract-call? .sbtc-liquid-staking transfer u1000000 tx-sender recipient none)

;; Check balance
(contract-call? .sbtc-liquid-staking get-balance user-address)

;; Get current value in sBTC
(let ((lstbtc-balance (unwrap-panic (contract-call? .sbtc-liquid-staking get-balance user)))
      (exchange-rate (contract-call? .sbtc-liquid-staking get-exchange-rate)))
  (/ (* lstbtc-balance exchange-rate) u1000000))
```

### For Frontend Applications

```javascript
// Stake sBTC
await contractCall({
  contractAddress: PROTOCOL_ADDRESS,
  contractName: 'sbtc-liquid-staking',
  functionName: 'stake-sbtc',
  functionArgs: [uintCV(stakeAmount)],
});

// Get user information
const userInfo = await callReadOnlyFunction({
  contractAddress: PROTOCOL_ADDRESS,
  contractName: 'sbtc-liquid-staking', 
  functionName: 'get-user-info',
  functionArgs: [principalCV(userAddress)],
});
```

## Deployment Checklist

- [ ] Deploy contract with appropriate owner address
- [ ] Set protocol parameters (fees, minimums)
- [ ] Verify SIP-010 compliance
- [ ] Test staking/unstaking flows
- [ ] Implement rewards distribution mechanism
- [ ] Set up monitoring and alerting
- [ ] Prepare emergency response procedures

## License

This contract is provided as-is for educational and development purposes. Ensure thorough testing and auditing before mainnet deployment.

## Contributing

When contributing to this protocol:

1. Maintain SIP-010 compliance
2. Add comprehensive tests for new features
3. Follow Clarity best practices
4. Update documentation for any interface changes
5. Consider economic implications of changes
