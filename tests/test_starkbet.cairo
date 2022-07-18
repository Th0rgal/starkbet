%lang starknet
from src.starkbet import (
    is_above_threshold,
    bet_up,
    bet_down,
    close_bet,
    redeem,
    get_up_liquidity,
    get_down_liquidity,
    get_bet_status,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256

@external
func test_is_above_threshold{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    let empiric_oracle_address = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4

    %{ stop_mock = mock_call(ids.empiric_oracle_address, "get_value", [1481820000000000000000, 18, 1658150145, 10]) %}

    let (above) = is_above_threshold('eth/usd', 1081820000000000000000)
    assert above = TRUE

    let (above) = is_above_threshold('eth/usd', 1981820000000000000000)
    assert above = FALSE

    %{ stop_mock() %}

    return ()
end

@external
func test_up_bet{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}():
    let eth_contract = 0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
    let empiric_oracle_address = 0x012fadd18ec1a23a160cc46981400160fbf4a7a5eed156c4669e39807265bcd4

    %{
        stop_warp = warp(0)
        stop_mock = mock_call(ids.eth_contract, "transferFrom", [1])
        stop_prank_callable = start_prank(1)
    %}

    # USER 1 BET UP WITH 600 TOKENS
    # in a real scenario we should first allow the contract to spend our funds
    let a_thousand = 1000000000000000000000
    bet_up('eth/usd', a_thousand, 3, 5, eth_contract, Uint256(600, 0))

    %{
        stop_warp()
        stop_mock()
        stop_prank_callable()
        stop_warp = warp(2)
        stop_mock = mock_call(ids.eth_contract, "transferFrom", [1])
        stop_prank_callable = start_prank(2)
                #stop_mock = mock_call(ids.empiric_oracle_address, "get_value", [1481820000000000000000, 18, 1658150145, 10])
    %}
    # USER 2 BET DOWN WITH 400 TOKENS
    bet_down('eth/usd', a_thousand, 3, 5, eth_contract, Uint256(400, 0))

    %{
        stop_warp()
        stop_mock()
        stop_prank_callable()
        stop_warp = warp(5)
        stop_mock = mock_call(ids.empiric_oracle_address, "get_value", [1481820000000000000000, 18, 1658150145, 10])
        stop_prank_callable = start_prank(1)
    %}
    let (up_liquidity) = get_up_liquidity('eth/usd', a_thousand, 3, 5, eth_contract)
    assert up_liquidity = Uint256(600, 0)
    let (down_liquidity) = get_down_liquidity('eth/usd', a_thousand, 3, 5, eth_contract)
    assert down_liquidity = Uint256(400, 0)

    let (status) = get_bet_status('eth/usd', a_thousand, 3, 5, eth_contract)
    assert status = 0

    # USER 1 CLOSES THE BET SO USER 1 CAN WIN 1000 TOKENS
    close_bet('eth/usd', a_thousand, 3, 5, eth_contract)

    let (status) = get_bet_status('eth/usd', a_thousand, 3, 5, eth_contract)
    assert status = 2

    %{
        stop_mock()
        stop_mock = mock_call(ids.eth_contract, "transfer", [1])
    %}
    # USER 1 REDEEMS THE BET TO WIN 1000 TOKENS
    redeem('eth/usd', a_thousand, 3, 5, eth_contract)

    return ()
end
