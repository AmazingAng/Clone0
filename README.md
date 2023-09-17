## Minimal Proxy Contract with `PUSH0`

**Minimal Proxy Contract with `PUSH0`, or `Clone0` in short, optimize the previous minimal proxy contract ([eip-1167](https://eips.ethereum.org/EIPS/eip-1167)) by 200 gas at deployment, 5 gas at runtime, while remaining the same functionalities.**

## Motivation

This standard tries to optimize the Minimal Proxy Contract with the newly added `PUSH0` opcodes. The main motivations are:

1. Reduce the contract bytecode size by `1` byte by removing a redundant `SWAP` opcode.
2. Reduce the runtime gas by replacing two `DUP` (cost `3` gas each) to two `PUSH0` (cost `2` gas each).
3. Increase the readability of the proxy contract by redesigning it from first principles with `PUSH0`.

## Test Cases

Test cases are performed using Foundry, which includes:

- invocation with no arguments.
- invocation with arguments.
- invocation with fixed length return values
- invocation with variable length return values
- invocation with revert
- deploy with minimal creation code (tested on Goerli testnet, [link](https://goerli.etherscan.io/address/0xb4f95ad6256a27a5629d9c4c71bff02bc373c9be#code))

You need to install [foundry](https://book.getfoundry.sh/getting-started/installation) to run the following test command:

```
forge test --evm-version shanghai
```

## Specification

### Standard Proxy Contract

The exact runtime code for the standard proxy contract with `PUSH0` is: 

```
365f5f375f5f365f73bebebebebebebebebebebebebebebebebebebebe5af43d5f5f3e5f3d91602a57fd5bf3
```

wherein the bytes at indices 9 - 28 (inclusive) are replaced with the 20 byte address of the master implementation contract. The length of the runtime code is `44` bytes.

The disassembly of the standard proxy contract code:

```shell
| pc   | op     | opcode         | stack              |
|------|--------|----------------|--------------------|
| [00] | 36     | CALLDATASIZE   | cds                |
| [01] | 5f     | PUSH0          | 0 cds              |
| [02] | 5f     | PUSH0          | 0 0 cds            |
| [03] | 37     | CALLDATACOPY   |                    |
| [04] | 5f     | PUSH0          | 0                  |
| [05] | 5f     | PUSH0          | 0 0                |
| [06] | 36     | CALLDATASIZE   | cds 0 0            |
| [07] | 5f     | PUSH0          | 0 cds 0 0          |
| [08] | 73bebe.| PUSH20 0xbebe. | 0xbebe. 0 cds 0 0  |
| [1d] | 5a     | GAS            | gas 0xbebe. 0 cds 0 0|
| [1e] | f4     | DELEGATECALL   | suc                |
| [1f] | 3d     | RETURNDATASIZE | rds suc            |
| [20] | 5f     | PUSH0          | 0 rds suc          |
| [21] | 5f     | PUSH0          | 0 0 rds suc        |
| [22] | 3e     | RETURNDATACOPY | suc                |
| [23] | 5f     | PUSH0          | 0 suc              |
| [24] | 3d     | RETURNDATASIZE | rds 0 suc          |
| [25] | 91     | SWAP2          | suc 0 rds          |
| [26] | 602a   | PUSH1 0x2a     | 0x2a suc 0 rds     |
| [27] | 57     | JUMPI          | 0 rds              |
| [29] | fd     | REVERT         |                    |
| [2a] | 5b     | JUMPDEST       | 0 rds              |
| [2b] | f3     | RETURN         |                    |
```

### Minimal Creation Code

The minimal creation code of the standard proxy contract is:

```
602c8060095f395ff3365f5f375f5f365f73bebebebebebebebebebebebebebebebebebebebe5af43d5f5f3e5f3d91602a57fd5bf3
```

where the first 9 bytes are the initcode: 

```
602c8060095f395ff3
```

The rest are runtime/contract code of the standard proxy. The length of the creation code is `53` bytes.

### Deploy with Solidity

The standard minimal contract can be deployed with Solidity using underlying contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Note: this contract requires `PUSH0`, which is available in solidity > 0.8.20 and EVM version > Shanghai
contract Clone0Factory {
    error FailedCreateClone();

    receive() external payable {}

    /**
     * @dev Deploys and returns the address of a clone0 (Minimal Proxy Contract with `PUSH0`) that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone0(address impl) public payable returns (address addr) {
        // first 18 bytes of the creation code 
        bytes memory data1 = hex"602c8060095f395ff3365f5f375f5f365f73";
        // last 15 bytes of the creation code
        bytes memory data2 = hex"5af43d5f5f3e5f3d91602a57fd5bf3";
        // complete the creation code of Clone0
        bytes memory _code = abi.encodePacked(data1, impl, data2);

        // deploy with create op
        assembly {
            // create(v, p, n)
            addr := create(callvalue(), add(_code, 0x20), mload(_code))
        }

        if (addr == address(0)) {
            revert FailedCreateClone();
        }
    }
}
```

This contract can also be found [here](./src/Clone0Factory.sol).

## Rationale

The contract is built from [first principals](https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract) utilizing the newly introduced `PUSH0` opcode. The essential components of the minimal proxy includes:

1. Copy the calldata with `CALLDATACOPY`.
2. Forward the calldata to the implementation contract using `DELEGATECALL`.
3. Copy the returned data from the `DELEGATECALL`.
4. Return the results or reverts the transaction based on wether the `DELEGATECALL` is successful.

### Step 1: Copy the Calldata

To copy the calldata, we need to provide the arguments for the `CALLDATACOPY` opcodes, which are `[0, 0, cds]`, where `cds` represents calldata size.

```shell
| pc   | op     | opcode         | stack              |
|------|--------|----------------|--------------------|
| [00] | 36     | CALLDATASIZE   | cds                |
| [01] | 5f     | PUSH0          | 0 cds              |
| [02] | 5f     | PUSH0          | 0 0 cds            |
| [03] | 37     | CALLDATACOPY   |                    |
```

### Step 2: Delegatecall

To forward the calldata to the delegate call, we need to prepare arguments for the `DELEGATECALL` opcodes, which are `[gas 0xbebe. 0 cds 0 0]`, where `gas` represents the remaining gas, `0xbebe.` represents the address of the implementation contract, and `suc` represents whether the delegatecall is successful. 

```shell
| pc   | op     | opcode         | stack              |
|------|--------|----------------|--------------------|
| [04] | 5f     | PUSH0          | 0                  |
| [05] | 5f     | PUSH0          | 0 0                |
| [06] | 36     | CALLDATASIZE   | cds 0 0            |
| [07] | 5f     | PUSH0          | 0 cds 0 0          |
| [08] | 73bebe.| PUSH20 0xbebe. | 0xbebe. 0 cds 0 0  |
| [1d] | 5a     | GAS            | gas 0xbebe. 0 cds 0 0|
| [1e] | f4     | DELEGATECALL   | suc                |
```

### Step 3: Copy the Returned Data from the `DELEGATECALL`

To copy the returndata, we need to provide the arguments for the `RETURNDATACOPY` opcodes, which are `[0, 0, red]`, where `rds` represents size of returndata from the `DELEGATECALL`.

```shell
| pc   | op     | opcode         | stack              |
|------|--------|----------------|--------------------|
| [1f] | 3d     | RETURNDATASIZE | rds suc            |
| [20] | 5f     | PUSH0          | 0 rds suc          |
| [21] | 5f     | PUSH0          | 0 0 rds suc        |
| [22] | 3e     | RETURNDATACOPY | suc                |
```

### Step 4: Return or Revert

Lastly we need to return the data or revert the transaction based on whether the `DELEGATECALL` is successful. There is no `if/else` in opcodes, so we need to use `JUMPI` and `JUMPDEST` instead. The auguments for `JUMPI` is `[0x2a, suc]`, where `0x2a` is the destination of the conditional jump.

 We also need to prepare the argument `[0, rds]` for `REVERT` and `RETURN` opcodes before the `JUMPI`, otherwise we have to prepare them twice. We cannot avoid the `SWAP` operation, because we can only get `rds` after the `DELEGATECALL`.

```shell
| pc   | op     | opcode         | stack              |
|------|--------|----------------|--------------------|
| [23] | 5f     | PUSH0          | 0 suc              |
| [24] | 3d     | RETURNDATASIZE | rds 0 suc          |
| [25] | 91     | SWAP2          | suc 0 rds          |
| [26] | 602a   | PUSH1 0x2a     | 0x2a suc 0 rds     |
| [27] | 57     | JUMPI          | 0 rds              |
| [29] | fd     | REVERT         |                    |
| [2a] | 5b     | JUMPDEST       | 0 rds              |
| [2b] | f3     | RETURN         |                    |
```

In the end, we arrived at the runtime code for Minimal Proxy Contract with `PUSH0`: 

```
365f5f375f5f365f73bebebebebebebebebebebebebebebebebebebebe5af43d5f5f3e5f3d91602a57fd5bf3
```

The length of the runtime code is `44` bytes, which reduced `1` byte from the previous Minimal Proxy Contract. Moreover, it replaced the `RETURNDATASIZE` and `DUP` operations with `PUSH0`, saving gas and increasing the code's readability. In summary, the Minimal Proxy Contract with `PUSH0` reduce `200` gas at deployment and `5` gas at runtime.

##  Backwards Compatibility

Because the new proxy contract standard uses the `PUSH0` opcode, it can only be used after the Shanghai Upgrade, otherwise, the contract cannot be deployed.

## Security Considerations

The new proxy contract standard is identical to the previous one (eip-1167). Here are the security considerations when using minimal proxy contracts:

**Security Considerations for Minimal Proxy Contracts:**

1. **Non-Upgradability**: Minimal Proxy Contracts delegate their logic to another contract (often termed the "implementation" or "logic" contract). This delegation is fixed upon deployment, meaning you can't change which implementation contract the proxy delegates to after its creation.
   
2. **Initialization Concerns**: Proxy contracts lack constructors, so you need to use an initialization function after deployment. Skipping this step could leave the contract unsafe.

3. **Safety of Logic Contract**: Vulnerabilities in the logic contract affect all associated proxy contracts.

4. **Transparency Issues**: Because of its complexity, users might see the proxy as an empty contract, making it challenging to trace back to the actual logic contract.

## Reference

1. Peter Murray (@yarrumretep), Nate Welch (@flygoing), Joe Messerman (@JAMesserman), "ERC-1167: Minimal Proxy Contract," Ethereum Improvement Proposals, no. 1167, June 2018. [Online serial]. Available: https://eips.ethereum.org/EIPS/eip-1167.

2. Alex Beregszaszi (@axic), Hugo De la cruz (@hugo-dc), Paweł Bylica (@chfast), "EIP-3855: PUSH0 instruction," Ethereum Improvement Proposals, no. 3855, February 2021. [Online serial]. Available: https://eips.ethereum.org/EIPS/eip-3855.

3. Martin Abbatemarco, Deep dive into the Minimal Proxy contract, https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract

4. 0age, The More-Minimal Proxy, https://medium.com/@0age/the-more-minimal-proxy-5756ae08ee48
