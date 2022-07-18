%lang starknet
from src.starkbet import bet_up, bet_down, is_above_threshold
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.bool import TRUE, FALSE

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
