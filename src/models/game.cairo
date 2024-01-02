use starknet::ContractAddress;
use colorit::models::cell::Color;
use colorit::models::player::StartingPosition;

const WIDTH: u32 = 12;
const HEIGHT: u32 = 12;

#[derive(Model, Drop, Serde)]
struct Game {
    #[key]
    game_id: u32,
    winner: Color,
    top: ContractAddress,
    bottom: ContractAddress
}

#[derive(Model, Drop, Serde)]
struct GameTurn {
    #[key]
    game_id: u32,
    player_starting_position: StartingPosition
}

trait GameTurnTrait {
    fn next_turn(self: @GameTurn) -> StartingPosition;
}
impl GameTurnImpl of GameTurnTrait {
    fn next_turn(self: @GameTurn) -> StartingPosition {
        match self.player_starting_position {
            StartingPosition::Top => StartingPosition::Bottom,
            StartingPosition::Bottom => StartingPosition::Top,
            StartingPosition::None => panic(array!['Illegal turn'])
        }
    }
}
