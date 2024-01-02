use starknet::ContractAddress;
use core::never;
use colorit::models::cell::{Cell, Vec2, Color};

// define the interface
#[starknet::interface]
trait IActions<ContractState> {
    fn color_it(self: @ContractState, color_to: Color, game_id: u32);
    fn spawn(
        self: @ContractState, top_address: ContractAddress, bottom_address: ContractAddress
    ) -> u32;
    fn color_cell(
        self: @ContractState, game_id: u32, position: Vec2, old_color: Color, new_color: Color
    ) -> ();
}

// dojo decorator
#[dojo::contract]
mod actions {
    use super::IActions;
    use core::option::OptionTrait;
    use starknet::{ContractAddress, get_caller_address, get_block_timestamp};
    use starknet::info::{get_block_number, get_contract_address};
    use pragma_lib::abi::{IRandomnessDispatcher, IRandomnessDispatcherTrait};
    use array::{ArrayTrait, SpanTrait};
    use openzeppelin::token::erc20::{interface::{IERC20Dispatcher, IERC20DispatcherTrait}};
    use traits::{TryInto, Into};
    use colorit::utils::{value_to_color};
    use colorit::models::game::{WIDTH, HEIGHT, GameTurn, Game, GameTurnImpl};
    use colorit::models::cell::{Cell, Vec2, Color};
    use colorit::models::player::{Player, StartingPosition};

    // impl: implement functions specified in trait
    #[external(v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(
            self: @ContractState, top_address: ContractAddress, bottom_address: ContractAddress
        ) -> u32 {
            let world = self.world_dispatcher.read();
            let game_id = world.uuid();

            // set Players
            set!(
                world,
                (
                    Player {
                        game_id, address: top_address, startingPostion: StartingPosition::Top
                    },
                    Player {
                        game_id, address: bottom_address, startingPostion: StartingPosition::Bottom
                    },
                )
            );

            // set Game and GameTurn    
            set!(
                world,
                (
                    Game {
                        game_id, top: top_address, bottom: bottom_address, winner: Color::None,
                    },
                    GameTurn { game_id, player_starting_position: StartingPosition::Top },
                )
            );

            let seed: u128 = 0xbdf7033ef9d6aed4c000bf6862a;
            
            // set Pieces
            let mut i: usize = 1;
            let width_plus_one = WIDTH + 1;
            let height_plus_one = HEIGHT + 1;
            loop {
                if i >= (WIDTH * height_plus_one) {
                    break;
                };

                let i_u128: u128 = i.try_into().unwrap();
                let field_color_felt: felt252 = (seed / (i_u128 + 1) % 5).into();

                let position = Vec2 { x: i % width_plus_one, y: (i / height_plus_one) + 1 };

                let color = value_to_color(field_color_felt);
                set!(world, (Cell { game_id, color: color, position: position, }));

                i += if (i + 1) % width_plus_one == 0 {
                    2
                } else {
                    1
                };
            };

            return game_id;
        }

        #[abi(embed_v0)]
        fn color_cell(
            self: @ContractState, game_id: u32, position: Vec2, old_color: Color, new_color: Color,
        ) -> () {
            let world = self.world_dispatcher.read();
            let (x, y) = (position.x, position.y);
            let mut current_cell: Cell = get!(world, (game_id, position), (Cell));
            if x == 0 || x > WIDTH || y == 0 || y > HEIGHT || current_cell.color != old_color {
                return;
            }

            // Change the color
            current_cell
                .color =
                    if current_cell.color == old_color {
                        new_color
                    } else {
                        current_cell.color
                    };

            set!(world, (current_cell));

            // Recursively apply to neighbors
            ActionsImpl::color_cell(
                self, game_id, Vec2 { x: x + 1, y: y }, old_color, new_color
            ); // Right
            ActionsImpl::color_cell(
                self, game_id, Vec2 { x: x - 1, y: y }, old_color, new_color
            ); // Right
            ActionsImpl::color_cell(
                self, game_id, Vec2 { x: x, y: y + 1 }, old_color, new_color
            ); // Right
            ActionsImpl::color_cell(
                self, game_id, Vec2 { x: x, y: y - 1 }, old_color, new_color
            ); // Right
        }

        fn color_it(self: @ContractState, color_to: Color, game_id: u32) {
            let world = self.world_dispatcher.read();
            let caller = get_caller_address();
            let mut game_turn: GameTurn = get!(world, game_id, (GameTurn));

            let player: Player = get!(world, (game_id, caller), (Player));

            assert(game_turn.player_starting_position == player.startingPostion, 'Not your turn');
            // let curr_position = player.startingPostion;
            let staring_vec_p1 = if player.startingPostion == StartingPosition::Top {
                Vec2 { x: 1, y: 1 }
            } else {
                Vec2 { x: WIDTH, y: HEIGHT }
            };
            let staring_vec_p2 = if player.startingPostion == StartingPosition::Top {
                Vec2 { x: WIDTH, y: HEIGHT }
            } else {
                Vec2 { x: 1, y: 1 }
            };

            let mut starting_cell_p1: Cell = get!(world, (game_id, staring_vec_p1), (Cell));
            let mut starting_cell_p2: Cell = get!(world, (game_id, staring_vec_p2), (Cell));

            assert(color_to != starting_cell_p2.color, 'Oponents color is the same');

            ActionsImpl::color_cell(
                self, game_id, staring_vec_p1, starting_cell_p1.color, color_to
            );

            assert(starting_cell_p1.color != starting_cell_p2.color, 'Game Over');

            // change turn
            game_turn.player_starting_position = game_turn.next_turn();
            set!(world, (game_turn));
        }
    }
}


#[cfg(test)]
mod tests {
    use colorit::models::cell::{Cell, Vec2, cell};
    use colorit::actions::{actions, IActionsDispatcher, IActionsDispatcherTrait};
    use colorit::models::player::{Color, player};
    use colorit::models::game::{Game, GameTurn, game, game_turn};
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo::test_utils::{spawn_test_world, deploy_contract, get_caller_address};

    fn setup_world() -> (IWorldDispatcher, IActionsDispatcher) {
        // models
        let mut models = array![
            game::TEST_CLASS_HASH,
            player::TEST_CLASS_HASH,
            game_turn::TEST_CLASS_HASH,
            cell::TEST_CLASS_HASH
        ];
        // deploy world with models
        let world = spawn_test_world(models);

        let contract_address = world
            .deploy_contract('salt', actions::TEST_CLASS_HASH.try_into().unwrap());
        let actions_system = IActionsDispatcher { contract_address };

        (world, actions_system)
    }

    #[test]
    #[available_gas(3000000000000000)]
    fn integration() {
        let white = get_caller_address();
        let black = starknet::contract_address_const::<0x02>();

        let (world, actions_system) = setup_world();

        //system calls
        let game_id = actions_system.spawn(white, black);

        actions_system.color_it(Color::Red, game_id);
        actions_system.color_it(Color::Blue, game_id);
        actions_system.color_it(Color::Green, game_id);

        let wp_curr_pos = Vec2 { x: 1, y: 1 };
        let one_one = get!(world, (game_id, wp_curr_pos), (Cell));

        assert(one_one.color == Color::Green, 'Color is not green');
    }
}
