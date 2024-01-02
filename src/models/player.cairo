use colorit::models::cell::Color;
use starknet::ContractAddress;

#[derive(Model, Drop, Serde)]
struct Player {
    #[key]
    game_id: u32,
    #[key]
    address: ContractAddress,
    startingPostion: StartingPosition
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum StartingPosition {
    Top,
    Bottom,
    None
}
