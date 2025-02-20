use dojo::event::EventStorage;
use dojo::world::{WorldStorage};
use starknet::{ContractAddress};
use dojo::model::{ModelStorage};
use origami_random::deck::{DeckTrait};
use origami_random::dice::{DiceTrait};
use core::dict::Felt252Dict;

use evolute_duel::{
    events::{BoardCreated, BoardCreateFromSnapshotFalied, BoardCreatedFromSnapshot}, models::{Board, Rules, Move},
    packing::{GameState, TEdge, Tile, PlayerSide},
};

use core::starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

use core::starknet::get_block_timestamp;


pub fn create_board(
    ref world: WorldStorage,
    player1: ContractAddress,
    player2: ContractAddress,
    mut board_id_generator: core::starknet::storage::StorageBase::<
        core::starknet::storage::Mutable<core::felt252>,
    >,
) -> Board {
    let board_id = board_id_generator.read();
    board_id_generator.write(board_id + 1);

    let rules: Rules = world.read_model(0);

    let (cities_on_edges, roads_on_edges) = rules.edges;
    let initial_edge_state = generate_initial_board_state(
        cities_on_edges, roads_on_edges, board_id,
    );

    let mut deck_rules_flat = flatten_deck_rules(@rules.deck);

    // Create an empty board.
    let mut tiles: Array<(u8, u8)> = ArrayTrait::new();
    tiles.append_span([((Tile::Empty).into(), 0); 64].span());

    let last_move_id = Option::None;
    let game_state = GameState::InProgress;

    let mut board = Board {
        id: board_id,
        initial_edge_state: initial_edge_state.clone(),
        available_tiles_in_deck: deck_rules_flat.clone(),
        top_tile: Option::None,
        state: tiles.clone(),
        player1: (player1, PlayerSide::Blue, rules.joker_number),
        player2: (player2, PlayerSide::Red, rules.joker_number),
        last_move_id,
        game_state,
    };

    let top_tile = draw_tile_from_board_deck(ref board);

    // Write the board to the world.
    world.write_model(@board);

    // Emit an event to the world to notify about the board creation.
    world
        .emit_event(
            @BoardCreated {
                board_id,
                initial_edge_state,
                available_tiles_in_deck: deck_rules_flat,
                top_tile,
                state: tiles,
                player1: board.player1,
                player2: board.player2,
                last_move_id,
                game_state,
            },
        );

    return board;
}

pub fn create_board_from_snapshot(
    ref world: WorldStorage,
    old_board_id: felt252,
    move_delta: u8,
    host_player: ContractAddress,
    mut board_id_generator: core::starknet::storage::StorageBase::<
        core::starknet::storage::Mutable<core::felt252>,
    >,
) -> felt252 {
    let new_board_id = board_id_generator.read();

    let old_board: Board = world.read_model(old_board_id);

    let mut deleted_tiles_positions: Felt252Dict<bool> = Default::default();
    let (_, player1_side, mut joker_number1) = old_board.player1;
    let (_, player2_side, mut joker_number2) = old_board.player2;
    let mut last_move_id = old_board.last_move_id;
    let mut top_tile = old_board.top_tile;
    let mut available_tiles_in_deck = old_board.available_tiles_in_deck.clone();
    for _ in 0..move_delta {
        if last_move_id.is_none() {
            world.emit_event(@BoardCreateFromSnapshotFalied {
                player: host_player,
                old_board_id,
                move_delta,
            });
            break;
        }
        let move_id = last_move_id.unwrap();
        let move: Move = world.read_model(move_id);
        
        last_move_id = move.prev_move_id;

        // If move is a skip, do not update the board state.
        if !move.is_joker && move.tile.is_none() {
            continue;
        }

        // Rememeber the deleted tile position
        let index: felt252 = (move.col * 8 + move.row).into();
        deleted_tiles_positions.insert(index, true);

        // Update jokers
        if move.is_joker {
            if move.player_side == player1_side {
                joker_number1 += 1;
            } else {
                joker_number2 += 1;
            }
        }
        // Update top tile and available tiles in deck 
        else {
            if top_tile.is_some() {
                available_tiles_in_deck.append(top_tile.unwrap());
            }
            top_tile = move.tile;
        }
    };

    // Update board state
    let mut updated_state: Array<(u8, u8)> = ArrayTrait::new();
    for i in 0..old_board.state.len() {
        //left tile if not deleted
        if !deleted_tiles_positions.get(i.into()) {
            updated_state.append(*old_board.state.at(i.into()));
        } 
        //empty tile if deleted
        else {
            updated_state.append((Tile::Empty.into(), 0));
        }
    };

    let new_board = Board {
        id: new_board_id,
        initial_edge_state: old_board.initial_edge_state,
        available_tiles_in_deck,
        top_tile,
        state: updated_state,
        player1: (host_player, player1_side, joker_number1),
        //TODO: we have no player2 now. Maybe we should wrap in Option there
        player2: (host_player, player2_side, joker_number2),
        last_move_id,
        game_state: GameState::InProgress,
    };

    world.write_model(@new_board);  
    board_id_generator.write(new_board_id + 1);

    world.emit_event(
        @BoardCreatedFromSnapshot {
            board_id: new_board_id,
            old_board_id,
            move_delta,
            initial_edge_state: new_board.initial_edge_state,
            available_tiles_in_deck: new_board.available_tiles_in_deck,
            top_tile: new_board.top_tile,
            state: new_board.state,
            player1: new_board.player1,
            player2: new_board.player2,
            last_move_id: new_board.last_move_id,
            game_state: new_board.game_state,
        },
    );

    new_board_id
}

pub fn update_board_state(
    ref board: Board, tile: Tile, rotation: u8, col: u8, row: u8, is_joker: bool, side: PlayerSide,
) {
    let mut updated_state: Array<(u8, u8)> = ArrayTrait::new();
    let index = (col * 8 + row).into();
    for i in 0..board.state.len() {
        if i == index {
            updated_state.append((tile.into(), rotation));
        } else {
            updated_state.append(*board.state.at(i.into()));
        }
    };

    board.state = updated_state;
}

pub fn update_board_joker_number(ref board: Board, side: PlayerSide, is_joker: bool) -> (u8, u8) {
    let (player1_address, player1_side, mut joker_number1) = board.player1;
    let (player2_address, player2_side, mut joker_number2) = board.player2;
    if is_joker {
        if side == player1_side {
            joker_number1 -= 1;
        } else {
            joker_number2 -= 1;
        }
    }

    board.player1 = (player1_address, player1_side, joker_number1);
    board.player2 = (player2_address, player2_side, joker_number2);

    (joker_number1, joker_number2)
}

/// Draws random tile from the board deck and updates the deck without the drawn tile.
pub fn draw_tile_from_board_deck(ref board: Board) -> Option<u8> {
    let avaliable_tiles: Array<u8> = board.available_tiles_in_deck.clone();
    if avaliable_tiles.len() == 0 {
        board.top_tile = Option::None;
        return Option::None;
    }
    let mut dice = DiceTrait::new(
        avaliable_tiles.len().try_into().unwrap(), 'SEED' + get_block_timestamp().into(),
    );
    let mut next_tile = dice.roll();

    let tile: u8 = *avaliable_tiles.at(next_tile.into());

    // Remove the drawn tile from the deck.
    let mut updated_available_tiles: Array<u8> = ArrayTrait::new();
    for i in 0..avaliable_tiles.len() {
        if i != next_tile.into() {
            updated_available_tiles.append(*avaliable_tiles.at(i.into()));
        }
    };

    board.available_tiles_in_deck = updated_available_tiles.clone();
    board.top_tile = Option::Some(tile.into());

    return Option::Some(tile);
}


fn generate_initial_board_state(
    cities_on_edges: u8, roads_on_edges: u8, board_id: felt252,
) -> Array<u8> {
    let mut initial_state: Array<u8> = ArrayTrait::new();

    for side in 0..4_u8 {
        let mut deck = DeckTrait::new(
            ('SEED' + side.into() + get_block_timestamp().into() + board_id).into(), 8,
        );
        let mut edge: Felt252Dict<u8> = Default::default();
        for i in 0..8_u8 {
            edge.insert(i.into(), TEdge::M.into());
        };
        for _ in 0..cities_on_edges {
            edge.insert(deck.draw().into() - 1, TEdge::C.into());
        };
        for _ in 0..roads_on_edges {
            edge.insert(deck.draw().into() - 1, TEdge::R.into());
        };

        for i in 0..8_u8 {
            initial_state.append(edge.get(i.into()));
        };
    };
    return initial_state;
}

fn flatten_deck_rules(deck_rules: @Array<u8>) -> Array<u8> {
    let mut deck_rules_flat = ArrayTrait::new();
    for tile_index in 0..24_u8 {
        let tile_type: u8 = tile_index;
        let tile_amount: u8 = *deck_rules.at(tile_index.into());
        for _ in 0..tile_amount {
            deck_rules_flat.append(tile_type);
        }
    };

    return deck_rules_flat;
}
