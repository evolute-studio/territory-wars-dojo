// Generated by dojo-bindgen on Thu, 6 Mar 2025 14:52:40 +0000. Do not modify this file manually.
using System;
using System.Threading.Tasks;
using Dojo;
using Dojo.Starknet;
using UnityEngine;
using dojo_bindings;
using System.Collections.Generic;
using System.Linq;
using Enum = Dojo.Starknet.Enum;
using BigInteger = System.Numerics.BigInteger;

// System definitions for `evolute_duel-game` contract
public class Game : MonoBehaviour {
    // The address of this contract
    public string contractAddress;

    
    // Call the `create_game` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> create_game(Account account) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "create_game",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `cancel_game` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> cancel_game(Account account) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "cancel_game",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `join_game` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> join_game(Account account, FieldElement host_player) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(host_player.Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "join_game",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `make_move` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> make_move(Account account, Option<byte> joker_tile, byte rotation, byte col, byte row) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(new FieldElement(Enum.GetIndex(joker_tile)).Inner);
		if (joker_tile is Option<byte>.Some) calldata.Add(new FieldElement(((Option<byte>.Some)joker_tile).value).Inner);
		calldata.Add(new FieldElement(rotation).Inner);
		calldata.Add(new FieldElement(col).Inner);
		calldata.Add(new FieldElement(row).Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "make_move",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `skip_move` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> skip_move(Account account) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "skip_move",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `create_snapshot` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> create_snapshot(Account account, FieldElement board_id, byte move_number) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(board_id.Inner);
		calldata.Add(new FieldElement(move_number).Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "create_snapshot",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `create_game_from_snapshot` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> create_game_from_snapshot(Account account, FieldElement snapshot_id) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(snapshot_id.Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "create_game_from_snapshot",
                calldata = calldata.ToArray()
            }
        });
    }
            

    
    // Call the `upgrade` system with the specified Account and calldata
    // Returns the transaction hash. Use `WaitForTransaction` to wait for the transaction to be confirmed.
    public async Task<FieldElement> upgrade(Account account, FieldElement new_class_hash) {
        List<dojo.FieldElement> calldata = new List<dojo.FieldElement>();
        calldata.Add(new_class_hash.Inner);

        return await account.ExecuteRaw(new dojo.Call[] {
            new dojo.Call{
                to = new FieldElement(contractAddress).Inner,
                selector = "upgrade",
                calldata = calldata.ToArray()
            }
        });
    }
            
}
        