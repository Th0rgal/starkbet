%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_add
from starkware.cairo.common.pow import pow

from starkware.starknet.common.syscalls import (
    get_contract_address,
    get_caller_address,
    get_block_timestamp,
)
from src.openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from contracts.oracle_controller.IEmpiricOracle import IEmpiricOracle

@storage_var
func bets_up(
    key : felt, target : felt, voting_expiration : felt, expiration : felt, token_contract : felt
) -> (amount : Uint256):
end

@storage_var
func bets_up_owners(
    owner : felt,
    key : felt,
    target : felt,
    voting_expiration : felt,
    expiration : felt,
    token_contract : felt,
) -> (amount : Uint256):
end

@storage_var
func bets_down(
    key : felt, target : felt, voting_expiration : felt, expiration : felt, token_contract : felt
) -> (amount : Uint256):
end

@storage_var
func bets_down_owners(
    owner : felt,
    key : felt,
    target : felt,
    voting_expiration : felt,
    expiration : felt,
    token_contract : felt,
) -> (amount : Uint256):
end

@external
func bet_up{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt,
    target : felt,
    voting_expiration : felt,
    expiration : felt,
    token_contract : felt,
    amount : Uint256,
) -> ():
    let (timestamp) = get_block_timestamp()
    assert_le(timestamp, voting_expiration)
    assert_le(voting_expiration, expiration)

    let (caller) = get_caller_address()
    let (contract_addr) = get_contract_address()
    IERC20.transferFrom(token_contract, caller, contract_addr, amount)
    let (old_amount) = bets_up.read(key, target, voting_expiration, expiration, token_contract)
    let (sum, _) = uint256_add(old_amount, amount)
    bets_up.write(key, target, voting_expiration, expiration, token_contract, sum)
    bets_up_owners.write(caller, key, target, voting_expiration, expiration, token_contract, amount)
    return ()
end

@external
func bet_down{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt,
    target : felt,
    voting_expiration : felt,
    expiration : felt,
    token_contract : felt,
    amount : Uint256,
) -> ():
    let (timestamp) = get_block_timestamp()
    assert_le(timestamp, voting_expiration)
    assert_le(voting_expiration, expiration)

    let (caller) = get_caller_address()
    let (contract_addr) = get_contract_address()
    IERC20.transferFrom(token_contract, caller, contract_addr, amount)
    let (old_amount) = bets_down.read(key, target, voting_expiration, expiration, token_contract)
    let (sum, _) = uint256_add(old_amount, amount)
    bets_down.write(key, target, voting_expiration, expiration, token_contract, sum)
    bets_down_owners.write(
        caller, key, target, voting_expiration, expiration, token_contract, amount
    )
    return ()
end

@external
func close_bet{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt,
    target : felt,
    voting_expiration : felt,
    expiration : felt,
    token_contract : felt,
    amount : Uint256,
) -> ():
    # assert voting_expiration > expiration
    assert_le(expiration + 1, voting_expiration)

    return ()
end

const EMPIRIC_ORACLE_ADDRESS = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4

@view
func is_above_threshold{syscall_ptr : felt*, range_check_ptr}(key : felt, threshold : felt) -> (
    is_above_threshold : felt
):
    alloc_locals

    let (eth_price, decimals, timestamp, num_sources_aggregated) = IEmpiricOracle.get_value(
        EMPIRIC_ORACLE_ADDRESS, key, 0
    )
    %{ print("result:", ids.eth_price) %}
    let (multiplier) = pow(10, decimals)

    let shifted_threshold = threshold * multiplier
    let (is_above_threshold) = is_le(shifted_threshold, eth_price)
    return (is_above_threshold)
end
