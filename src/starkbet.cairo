%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import Uint256, uint256_add, uint256_unsigned_div_rem
from starkware.starknet.common.syscalls import (
    get_contract_address,
    get_caller_address,
    get_block_timestamp,
)
from cairo_contracts.src.openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from Empiric.contracts.oracle_controller.IEmpiricOracle import IEmpiricOracle

const EMPIRIC_ORACLE_ADDRESS = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4

struct BetResult:
    member total : Uint256
    member shares : Uint256
end

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

@storage_var
func bet_result_down(
    key : felt, target : felt, voting_expiration : felt, expiration : felt, token_contract : felt
) -> (result : BetResult):
end

@storage_var
func bet_result_up(
    key : felt, target : felt, voting_expiration : felt, expiration : felt, token_contract : felt
) -> (result : BetResult):
end

@storage_var
func profits(token_contract : felt) -> (amount : Uint256):
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
    key : felt, target : felt, voting_expiration : felt, expiration : felt, token_contract : felt
) -> ():
    # assert voting_expiration > expiration
    assert_le(expiration + 1, voting_expiration)
    let (up) = is_above_threshold(key, target)
    let (amount_up) = bets_up.read(key, target, voting_expiration, expiration, token_contract)
    let (amount_down) = bets_down.read(key, target, voting_expiration, expiration, token_contract)
    let (total, _) = uint256_add(amount_up, amount_down)
    if up == TRUE:
        # people voting UP WON because price  >= target
        bet_result_up.write(
            key, target, voting_expiration, expiration, token_contract, BetResult(total, amount_up)
        )
        return ()
    else:
        # people voting DOWN WON because price < target
        bet_result_down.write(
            key,
            target,
            voting_expiration,
            expiration,
            token_contract,
            BetResult(total, amount_down),
        )
        return ()
    end
end

func is_above_threshold{syscall_ptr : felt*, range_check_ptr}(key : felt, threshold : felt) -> (
    is_above_threshold : felt
):
    alloc_locals
    let (eth_price, _, _, _) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, key, 0)
    let (is_above_threshold) = is_le(threshold, eth_price)
    return (is_above_threshold)
end

@external
func take_profits_up{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt, target : felt, voting_expiration : felt, expiration : felt, token_contract : felt
) -> ():
    # result example: { total: 20, shares : 15 }
    let (result : BetResult) = bet_result_up.read(
        key, target, voting_expiration, expiration, token_contract
    )

    let (shares : Uint256) = bets_up.read(
        key, target, voting_expiration, expiration, token_contract
    )

    # if we own shares, we can keep: shares * total / total_shares
    let (user_profit : Uint256, rounding : Uint256) = uint256_unsigned_div_rem(
        result.total * shares, result.shares
    )

    # rounding error is kept by the protocol: that wouldn't be fair to give a better share to some users
    let (prev_protocol_profit : Uint256) = profits.read(token_contract)
    let (protocol_profit : Uint256) = uint256_add(prev_protocol_profit, rounding)
    profits.write(token_contract, protocol_profit)

    let (caller) = get_caller_address()
    IERC20.transfer(token_contract, caller, user_profit)
end
