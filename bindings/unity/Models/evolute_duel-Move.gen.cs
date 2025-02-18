// Generated by dojo-bindgen on Tue, 18 Feb 2025 17:31:12 +0000. Do not modify this file manually.
using System;
using Dojo;
using Dojo.Starknet;
using System.Reflection;
using System.Linq;
using System.Collections.Generic;
using Enum = Dojo.Starknet.Enum;
using BigInteger = System.Numerics.BigInteger;

// Type definition for `core::option::Option::<evolute_duel::models::Tile>` enum
public abstract record Option<A>() : Enum {
    public record Some(A value) : Option<A>;
    public record None() : Option<A>;
}


// Model definition for `evolute_duel::models::Move` model
public class evolute_duel_Move : ModelInstance {
    [ModelField("id")]
        public FieldElement id;

        [ModelField("tile")]
        public Option<Tile> tile;

    // Start is called before the first frame update
    void Start() {
    }

    // Update is called once per frame
    void Update() {
    }
}

        