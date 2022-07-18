%lang starknet
from starkware.cairo.common.math import assert_nn, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.pow import pow
from starkware.cairo.common.uint256 import (
    Uint256,
    uint256_add,
    uint256_mul,
    uint256_unsigned_div_rem,
)
from starkware.starknet.common.syscalls import (
    get_contract_address,
    get_caller_address,
    get_block_timestamp,
)
from cairo_contracts.src.openzeppelin.token.erc20.interfaces.IERC20 import IERC20
from Empiric.contracts.oracle_controller.IEmpiricOracle import IEmpiricOracle

const EMPIRIC_ORACLE_ADDRESS = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4

@storage_var
func bets_up(
    key : felt, target : felt, betting_expiration : felt, expiration : felt, token_contract : felt
) -> (amount : Uint256):
end

@storage_var
func bets_up_owners(
    owner : felt,
    key : felt,
    target : felt,
    betting_expiration : felt,
    expiration : felt,
    token_contract : felt,
) -> (amount : Uint256):
end

@storage_var
func bets_down(
    key : felt, target : felt, betting_expiration : felt, expiration : felt, token_contract : felt
) -> (amount : Uint256):
end

@storage_var
func bets_down_owners(
    owner : felt,
    key : felt,
    target : felt,
    betting_expiration : felt,
    expiration : felt,
    token_contract : felt,
) -> (amount : Uint256):
end

# 0 if no winner, 1 if down, 2 if up
@storage_var
func won(
    key : felt, target : felt, betting_expiration : felt, expiration : felt, token_contract : felt
) -> (winner : felt):
end

@storage_var
func profits(token_contract : felt) -> (amount : Uint256):
end

@external
func bet_up{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt,
    target : felt,
    betting_expiration : felt,
    expiration : felt,
    token_contract : felt,
    amount : Uint256,
) -> ():
    let (timestamp) = get_block_timestamp()
    assert_le(timestamp, betting_expiration)
    assert_le(betting_expiration, expiration)

    let (caller) = get_caller_address()
    let (contract_addr) = get_contract_address()
    let (transfered) = IERC20.transferFrom(token_contract, caller, contract_addr, amount)
    assert transfered = TRUE
    let (old_amount) = bets_up.read(key, target, betting_expiration, expiration, token_contract)
    let (sum, _) = uint256_add(old_amount, amount)
    bets_up.write(key, target, betting_expiration, expiration, token_contract, sum)
    bets_up_owners.write(caller, key, target, betting_expiration, expiration, token_contract, amount)
    return ()
end

@external
func bet_down{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt,
    target : felt,
    betting_expiration : felt,
    expiration : felt,
    token_contract : felt,
    amount : Uint256,
) -> ():
    let (timestamp) = get_block_timestamp()
    assert_le(timestamp, betting_expiration)
    assert_le(betting_expiration, expiration)

    let (caller) = get_caller_address()
    let (contract_addr) = get_contract_address()
    let (transfered) = IERC20.transferFrom(token_contract, caller, contract_addr, amount)
    assert transfered = TRUE
    let (old_amount) = bets_down.read(key, target, betting_expiration, expiration, token_contract)
    let (sum, _) = uint256_add(old_amount, amount)
    bets_down.write(key, target, betting_expiration, expiration, token_contract, sum)
    bets_down_owners.write(
        caller, key, target, betting_expiration, expiration, token_contract, amount
    )
    return ()
end

@external
func close_bet{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt, target : felt, betting_expiration : felt, expiration : felt, token_contract : felt
) -> ():
    # assert timestamp >= expiration
    let (timestamp) = get_block_timestamp()
    assert_le(timestamp, expiration)
    let (up) = is_above_threshold(key, target)
    let (amount_up) = bets_up.read(key, target, betting_expiration, expiration, token_contract)
    let (amount_down) = bets_down.read(key, target, betting_expiration, expiration, token_contract)
    let (total, _) = uint256_add(amount_up, amount_down)
    won.write(key, target, betting_expiration, expiration, token_contract, up + 1)
    return ()
end

func is_above_threshold{syscall_ptr : felt*, range_check_ptr}(key : felt, threshold : felt) -> (
    is_above_threshold : felt
):
    alloc_locals
    let (eth_price, _, _, _) = IEmpiricOracle.get_value(EMPIRIC_ORACLE_ADDRESS, key, 0)
    let (is_above_threshold) = is_le(threshold, eth_price)
    return (is_above_threshold)
end

func has_won{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt,
    key : felt,
    target : felt,
    betting_expiration : felt,
    expiration : felt,
    token_contract : felt,
) -> (total_tokens : Uint256, total_shares : Uint256, user_shares : Uint256):
    alloc_locals
    let (tokens_up) = bets_up.read(key, target, betting_expiration, expiration, token_contract)
    let (tokens_down) = bets_down.read(key, target, betting_expiration, expiration, token_contract)
    let (total_tokens, _) = uint256_add(tokens_up, tokens_down)

    let (winner) = won.read(key, target, betting_expiration, expiration, token_contract)
    if winner == 0:
        assert 1 = 0
    end

    # winner is down
    if winner == 1:
        let (shares) = bets_down_owners.read(
            owner, key, target, betting_expiration, expiration, token_contract
        )
        return (total_tokens, tokens_down, shares)
    end

    # winner is up
    let (shares) = bets_up_owners.read(
        owner, key, target, betting_expiration, expiration, token_contract
    )
    return (total_tokens, tokens_up, shares)
end

@external
func redeem{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    key : felt, target : felt, betting_expiration : felt, expiration : felt, token_contract : felt
) -> ():
    alloc_locals
    # result example: { total_tokens: 20, total_shares : 15, user_shares : 5 }

    let (caller) = get_caller_address()
    let (total_tokens : Uint256, total_shares : Uint256, user_shares : Uint256) = has_won(
        caller, key, target, betting_expiration, expiration, token_contract
    )

    # if we own shares, we can keep: shares * total / total_shares
    let (multiplied_low : Uint256, multiplied_high : Uint256) = uint256_mul(
        user_shares, total_tokens
    )
    let (user_profit_a : Uint256, rounding_a : Uint256) = uint256_unsigned_div_rem(
        multiplied_low, total_shares
    )
    let (user_profit_b : Uint256, rounding_b : Uint256) = uint256_unsigned_div_rem(
        multiplied_high, total_shares
    )

    let (user_profit : Uint256, _) = uint256_add(user_profit_a, user_profit_b)
    let (rounding : Uint256, _) = uint256_add(rounding_a, rounding_b)

    # rounding error is kept by the protocol: that wouldn't be fair to give a better share to some users
    let (prev_protocol_profit : Uint256) = profits.read(token_contract)
    let (protocol_profit : Uint256, _) = uint256_add(prev_protocol_profit, rounding)
    profits.write(token_contract, protocol_profit)

    let (transfered) = IERC20.transfer(token_contract, caller, user_profit)
    assert transfered = TRUE
    return ()
end
