use starknet::ContractAddress;

// define the interface
#[starknet::interface]
pub trait IGame<T> {
    fn create_game(ref self: T);
    fn cancel_game(ref self: T);
    fn join_game(ref self: T, host_player: ContractAddress);
    fn make_move(ref self: T, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8);
    // fn skip_move(ref self: T);
    fn check(ref self: T);
}

// dojo decorator
#[dojo::contract]
pub mod game {
    use super::{IGame};
    use starknet::{ContractAddress, get_caller_address};
    use evolute_duel::{
        models::{Board, Rules, Move, Game},
        events::{
            GameCreated, GameCreateFailed, GameJoinFailed, GameStarted, GameCanceled, BoardUpdated,
            PlayerNotInGame, NotYourTurn, NotEnoughJokers, GameFinished, 
        },
        systems::helpers::board::{create_board, draw_tile_from_board_deck, update_board_state},
        packing::{GameStatus, Tile, GameState},
    };

    use dojo::event::EventStorage;
    use dojo::model::{ModelStorage};

    use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        board_id_generator: felt252,
        move_id_generator: felt252,
    }


    fn dojo_init(self: @ContractState) {
        let mut world = self.world(@"evolute_duel");
        let id = 0;
        let deck: Array<u8> = array![
            1, // CCCC
            1, // FFFF
            0, // RRRR - not in the deck
            4, // CCCF
            3, // CCCR
            4, // CFFF
            0, // FFFR
            0, // CRRR - not in the deck
            4, // FRRR
            0, // CCFF - not in the deck
            6, // CFCF
            0, // CCRR - not in the deck
            0, // CRCR - not in the deck
            9, // FFRR
            8, // FRFR
            0, // CCFR - not in the deck
            0, // CCRF - not in the deck
            7, // CFCR
            4, // CFFR
            4, // CFRF
            0, // CRFF - not in the deck
            3, // CRRF
            4, // CRFR
            4 // CFRR
        ];
        let edges = (1, 1);
        let joker_number = 3;

        let rules = Rules { id, deck, edges, joker_number };
        world.write_model(@rules);
    }

    #[abi(embed_v0)]
    impl GameImpl of IGame<ContractState> {
        fn create_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let mut status = game.status;

            if status == GameStatus::InProgress || status == GameStatus::Created {
                world.emit_event(@GameCreateFailed { host_player, status });
                return;
            }

            status = GameStatus::Created;
            game.status = status;
            game.board_id = Option::None;

            world.write_model(@game);

            world.emit_event(@GameCreated { host_player, status });
        }

        fn cancel_game(ref self: ContractState) {
            let mut world = self.world_default();

            let host_player = get_caller_address();

            let mut game: Game = world.read_model(host_player);
            let status = game.status;

            if status == GameStatus::Created {
                let new_status = GameStatus::Canceled;
                game.status = new_status;

                world.write_model(@game);

                world.emit_event(@GameCanceled { host_player, status: new_status });
            } else {
                world.emit_event(@GameCreateFailed { host_player, status });
            }
        }

        fn join_game(ref self: ContractState, host_player: ContractAddress) {
            let mut world = self.world_default();
            let guest_player = get_caller_address();

            let mut host_game: Game = world.read_model(host_player);
            let host_game_status = host_game.status;

            let mut guest_game: Game = world.read_model(guest_player);
            let guest_game_status = guest_game.status;

            if host_game_status != GameStatus::Created
                || guest_game_status == GameStatus::Created
                || guest_game_status == GameStatus::InProgress
                || host_player == guest_player {
                world
                    .emit_event(
                        @GameJoinFailed {
                            host_player, guest_player, host_game_status, guest_game_status,
                        },
                    );
                return;
            }
            host_game.status = GameStatus::InProgress;
            guest_game.status = GameStatus::InProgress;

            let board = create_board(ref world, host_player, guest_player, self.board_id_generator);
            let board_id = board.id;
            host_game.board_id = Option::Some(board_id);
            guest_game.board_id = Option::Some(board_id);

            world.write_model(@host_game);
            world.write_model(@guest_game);

            world.emit_event(@GameStarted { host_player, guest_player, board_id });
        }

        fn make_move(
            ref self: ContractState, joker_tile: Option<u8>, rotation: u8, col: u8, row: u8,
        ) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);
            let move_id = self.move_id_generator.read();

            let tile: Tile = match joker_tile {
                Option::Some(tile_index) => { tile_index.into() },
                Option::None => {
                    match @board.top_tile {
                        Option::Some(top_tile) => { (*top_tile).into() },
                        Option::None => {
                            //TODO: Error: no joker and no top tile. Move is impossible
                            return;
                        },
                    }
                },
            };

            let (player1_address, player1_side, joker_number1, _) = board.player1;
            let (player2_address, player2_side, joker_number2, _) = board.player2;

            let (player_side, joker_number) = if player == player1_address {
                (player1_side, joker_number1)
            } else if player == player2_address {
                (player2_side, joker_number2)
            } else {
                //TODO: Error: player is not in the game
                world.emit_event(@PlayerNotInGame { player_id: player, board_id });
                return;
            };

            //check if enough jokers
            if joker_tile.is_some() && joker_number == 0 {
                world.emit_event(@NotEnoughJokers { player_id: player, board_id });
                return;
            }

            //check if it is the player's turn
            let prev_move_id = board.last_move_id;
            if prev_move_id.is_some() {
                let prev_move_id = prev_move_id.unwrap();
                let prev_move: Move = world.read_model(prev_move_id);
                let prev_player_side = prev_move.player_side;

                if player_side == prev_player_side {
                    //TODO: Error: turn of the other player
                    world.emit_event(@NotYourTurn { player_id: player, board_id });
                    return;
                }
            };

            let move = Move {
                id: move_id,
                prev_move_id: board.last_move_id,
                player_side,
                tile: Option::Some(tile.into()),
                rotation: rotation,
                col,
                row,
                is_joker: joker_tile.is_some(),
            };

            //TODO: check if the move is valid

            draw_tile_from_board_deck(ref board);

            //TODO: update board state
            update_board_state(
                ref board, tile, rotation, col, row, joker_tile.is_some(), player_side,
            );

            board.last_move_id = Option::Some(move_id);
            self.move_id_generator.write(move_id + 1);
            world.write_model(@move);
            world.write_model(@board);

            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        initial_edge_state: board.initial_edge_state,
                        available_tiles_in_deck: board.available_tiles_in_deck,
                        top_tile: board.top_tile,
                        state: board.state,
                        player1: board.player1,
                        player2: board.player2,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
            // // Check if the game is in progress.

        }

        // fn skip_move(ref self: ContractState) {
        //     let mut world = self.world_default();
        //     let player = get_caller_address();
        //     let game: Game = world.read_model(player);

        //     if game.board_id.is_none() {
        //         world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
        //         return;
        //     }

        //     let board_id = game.board_id.unwrap();
        //     let mut board: Board = world.read_model(board_id);
        // }

        fn check(ref self: ContractState) {
            let mut world = self.world_default();
            let player = get_caller_address();
            let game: Game = world.read_model(player);

            if game.board_id.is_none() {
                world.emit_event(@PlayerNotInGame { player_id: player, board_id: 0 });
                return;
            }

            let board_id = game.board_id.unwrap();
            let mut board: Board = world.read_model(board_id);

            let (player1_address, player1_side, joker_number1, mut player1_checked) = board.player1;
            let (player2_address, player2_side, joker_number2, mut player2_checked) = board.player2;

            if player == player1_address {
                player1_checked = true;
            } else {
                player2_checked = true;
            };

            board.player1 = (player1_address, player1_side, joker_number1, player1_checked);
            board.player2 = (player2_address, player2_side, joker_number2, player2_checked);

            if player1_checked && player2_checked {
                //TODO: FINISH THE GAME
                board.game_state = GameState::Finished;
                let mut host_game: Game = world.read_model(player1_address);
                let mut guest_game: Game = world.read_model(player2_address);
                host_game.status = GameStatus::Finished;
                guest_game.status = GameStatus::Finished;

                world.write_model(@host_game);
                world.write_model(@guest_game);

                world.emit_event(@GameFinished { host_player: player1_address, board_id });
                world.emit_event(@GameFinished { host_player: player2_address, board_id });
            }

            world.write_model(@board);
            world
                .emit_event(
                    @BoardUpdated {
                        board_id: board.id,
                        initial_edge_state: board.initial_edge_state,
                        available_tiles_in_deck: board.available_tiles_in_deck,
                        top_tile: board.top_tile,
                        state: board.state,
                        player1: board.player1,
                        player2: board.player2,
                        last_move_id: board.last_move_id,
                        game_state: board.game_state,
                    },
                );
        }
    }


    // fn is_move_valid(
    //     mut board: Board, mut tile: Option<Tile>, rotation: u8, col: u8, row: u8, is_joker: bool,
    // ) -> bool {
    //     // Check if the tile on top of the random deck.
    //     if board.random_deck.is_empty() {
    //         return false;
    //     }

    //     if is_joker {
    //         if tile == Option::None {
    //             return false;
    //         }
    //     } else {
    //         tile = Option::Some(board.random_deck.pop_front().unwrap().into());
    //     }

    //     // Check if the tile is already placed on the board.
    //     if board.tiles.get((col + row * 8).into()).is_some() {
    //         return false;
    //     }

    //     let tile: TileStruct = tile.unwrap().into();
    //     // Check if the tile can be placed on the board.
    //     if !is_tile_allowed_to_place(board, tile, rotation, col, row) {
    //         return false;
    //     }

    //     return true;
    // }

    // fn is_tile_allowed_to_place(
    //     board: Board, tile: TileStruct, rotation: u8, col: u8, row: u8,
    // ) -> bool {
    //     let edges: [TEdge; 4] = [
    //         *tile.edges.span()[((0 + rotation) % 4).into()],
    //         *tile.edges.span()[((1 + rotation) % 4).into()],
    //         *tile.edges.span()[((2 + rotation) % 4).into()],
    //         *tile.edges.span()[((3 + rotation) % 4).into()],
    //     ];
    //     let edges = edges.span();

    //     let mut is_move_valid = true;

    //     for i in 0..4_u8 {
    //         let mut neighbor_col = col;
    //         let mut neighbor_row = row;
    //         if (i == 0) {
    //             if neighbor_row == 0 {
    //                 continue;
    //             }
    //             neighbor_row -= 1;
    //         } else if (i == 1) {
    //             if neighbor_col == 7 {
    //                 continue;
    //             }
    //             neighbor_col += 1;
    //         } else if (i == 2) {
    //             if neighbor_row == 7 {
    //                 continue;
    //             }
    //             neighbor_row += 1;
    //         } else {
    //             if neighbor_col == 0 {
    //                 continue;
    //             }
    //             neighbor_col -= 1;
    //         }

    //         let neighbor_tile: Option<TileStruct> = *board
    //             .tiles
    //             .at((neighbor_col + neighbor_row * 8).into());

    //         if neighbor_tile.is_some() {
    //             let neighbor_tile: TileStruct = neighbor_tile.unwrap();
    //             let neighbor_edges = neighbor_tile.edges.span();
    //             let neighbor_edge: TEdge = *neighbor_edges.at(((i + 2) % 4).into());

    //             if *edges.at(i.into()) != neighbor_edge {
    //                 is_move_valid = false;
    //                 break;
    //             }
    //         }
    //     };

    //     return true;
    // }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"evolute_duel")
        }
    }
}
