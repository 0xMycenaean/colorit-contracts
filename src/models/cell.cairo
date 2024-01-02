use colorit::models::game::{WIDTH, HEIGHT};
use starknet::ContractAddress;

#[derive(Model, Drop, Serde)]
struct Cell {
    #[key]
    game_id: u32,
    #[key]
    position: Vec2,
    color: Color,
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Vec2 {
    x: u32,
    y: u32
}

#[derive(Serde, Drop, Copy, PartialEq, Introspect)]
enum Color {
    Red,
    Blue,
    Green,
    Yellow,
    Purple,
    None
}
