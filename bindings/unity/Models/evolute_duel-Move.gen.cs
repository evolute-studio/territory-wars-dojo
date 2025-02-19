// Generated by dojo-bindgen on Wed, 19 Feb 2025 20:26:44 +0000. Do not modify this file manually.
using System;
using Dojo;
using Dojo.Starknet;
using System.Reflection;
using System.Linq;
using System.Collections.Generic;
using Enum = Dojo.Starknet.Enum;
using BigInteger = System.Numerics.BigInteger;

// Type definition for `core::option::Option::<core::felt252>` enum
public abstract record Option<A>() : Enum {
    public record Some(A value) : Option<A>;
    public record None() : Option<A>;
}

// Type definition for `evolute_duel::packing::PlayerSide` enum
public abstract record PlayerSide() : Enum {
    public record Blue() : PlayerSide;
    public record Red() : PlayerSide;
}


// Model definition for `evolute_duel::models::Move` model
public class evolute_duel_Move : ModelInstance {
    [ModelField("id")]
        public FieldElement id;

        [ModelField("player_side")]
        public PlayerSide player_side;

        [ModelField("prev_move_id")]
        public Option<FieldElement> prev_move_id;

        [ModelField("tile")]
        public Option<byte> tile;

        [ModelField("rotation")]
        public byte rotation;

        [ModelField("col")]
        public byte col;

        [ModelField("row")]
        public byte row;

        [ModelField("is_joker")]
        public bool is_joker;

    // Start is called before the first frame update
    void Start() {
    }

    // Update is called once per frame
    void Update() {
    }
}

        