use dojo::model::ModelStorage;
use evolute_duel::models::scoring::{RoadNode};
use dojo::world::{WorldStorage};
//Union find on RoadNode
pub fn find(ref world: WorldStorage, board_id: felt252, position: u8) -> RoadNode {
    let node: RoadNode = world.read_model((board_id, position));
    let mut current = node;
    if current.parent != current.position {
        current.parent = find(ref world, board_id, current.parent).position;
    }
    world.write_model(@current);

    world.read_model((board_id, current.parent))
}

pub fn union(
    ref world: WorldStorage, board_id: felt252, position1: u8, position2: u8, in_tile: bool,
) -> RoadNode {
    let mut root1 = find(ref world, board_id, position1);
    let mut root2 = find(ref world, board_id, position2);

    if root1.position == root2.position {
        if !in_tile {
            root1.open_edges -= 2;
        }
        world.write_model(@root1);
        return root1;
    }
    if root1.rank > root2.rank {
        root2.parent = root1.position;
        root1.blue_points += root2.blue_points;
        root1.red_points += root2.red_points;
        root1.open_edges += root2.open_edges;
        if !in_tile {
            root1.open_edges -= 2;
        }
        world.write_model(@root2);
        world.write_model(@root1);
        return root1;
    } else if root1.rank < root2.rank {
        root1.parent = root2.position;
        root2.blue_points += root1.blue_points;
        root2.red_points += root1.red_points;
        root2.open_edges += root1.open_edges;
        if !in_tile {
            root2.open_edges -= 2;
        }
        world.write_model(@root1);
        world.write_model(@root2);
        return root2;
    } else {
        root2.parent = root1.position;
        root1.rank += 1;
        root1.blue_points += root2.blue_points;
        root1.red_points += root2.red_points;
        root1.open_edges += root2.open_edges;
        if !in_tile {
            root1.open_edges -= 2;
        }
        world.write_model(@root2);
        world.write_model(@root1);
        return root1;
    }
}

pub fn connected(ref world: WorldStorage, board_id: felt252, position1: u8, position2: u8) -> bool {
    let root1 = find(ref world, board_id, position1);
    let root2 = find(ref world, board_id, position2);
    return root1.position == root2.position;
}

#[cfg(test)]
mod tests {
    use super::*;
    use dojo_cairo_test::WorldStorageTestTrait;
    use dojo::model::{ModelStorage, ModelStorageTest};
    use dojo::world::WorldStorageTrait;
    use dojo_cairo_test::{
        spawn_test_world, NamespaceDef, TestResource, ContractDefTrait, ContractDef,
    };

    use evolute_duel::{
        models::{Board, m_Board, Move, m_Move, Rules, m_Rules, Game, m_Game, RoadNode, m_RoadNode},
        events::{
            BoardCreated, e_BoardCreated, RulesCreated, e_RulesCreated, Moved, e_Moved, InvalidMove,
            e_InvalidMove, GameFinished, e_GameFinished, GameStarted, e_GameStarted, GameCreated,
            e_GameCreated, GameCreateFailed, e_GameCreateFailed, GameCanceled, e_GameCanceled,
        },
        packing::{GameStatus},
    };
    use evolute_duel::systems::game::{game, IGameDispatcher, IGameDispatcherTrait};

    use starknet::testing;

    fn namespace_def() -> NamespaceDef {
        NamespaceDef {
            namespace: "evolute_duel",
            resources: [
                TestResource::Model(m_Board::TEST_CLASS_HASH),
                TestResource::Model(m_RoadNode::TEST_CLASS_HASH),
            ]
                .span(),
        }
    }

    fn contract_defs() -> Span<ContractDef> {
        [].span()
    }

    #[test]
    fn test_find() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Register the resources.
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());

        let board_id = 1;
        let position = 0;
        world
            .write_model(
                @RoadNode {
                    board_id,
                    position,
                    parent: position,
                    rank: 1,
                    blue_points: 0,
                    red_points: 0,
                    open_edges: 4,
                    contested: false,
                },
            );
        let node = find(ref world, board_id, position);
        assert!(node.position == position, "Position should be the same");
    }

    #[test]
    fn test_union() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Register the resources.
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());
        let board_id = 1;
        world
            .write_model(
                @RoadNode {
                    board_id,
                    position: 0,
                    parent: 0,
                    rank: 1,
                    blue_points: 1,
                    red_points: 2,
                    open_edges: 4,
                    contested: false,
                },
            );
        world
            .write_model(
                @RoadNode {
                    board_id,
                    position: 1,
                    parent: 1,
                    rank: 1,
                    blue_points: 2,
                    red_points: 3,
                    open_edges: 4,
                    contested: false,
                },
            );

        let root = union(ref world, board_id, 0, 1, false);
        let root1 = find(ref world, board_id, 0);
        let root2 = find(ref world, board_id, 1);
        assert!(
            find(ref world, board_id, 0).position == find(ref world, board_id, 1).position,
            "Position should be the same",
        );
    }

    #[test]
    fn test_connected() {
        // Initialize test environment
        let caller = starknet::contract_address_const::<0x0>();
        let ndef = namespace_def();

        // Register the resources.
        let mut world = spawn_test_world([ndef].span());

        // Ensures permissions and initializations are synced.
        world.sync_perms_and_inits(contract_defs());
        let board_id = 1;
        world
            .write_model(
                @RoadNode {
                    board_id,
                    position: 0,
                    parent: 0,
                    rank: 1,
                    blue_points: 1,
                    red_points: 2,
                    open_edges: 4,
                    contested: false,
                },
            );
        world
            .write_model(
                @RoadNode {
                    board_id,
                    position: 1,
                    parent: 1,
                    rank: 1,
                    blue_points: 2,
                    red_points: 3,
                    open_edges: 4,
                    contested: false,
                },
            );

        let root = union(ref world, board_id, 0, 1, false);
        let connected = connected(ref world, board_id, 0, 1);
        assert!(connected, "Nodes should be connected");
    }
}
