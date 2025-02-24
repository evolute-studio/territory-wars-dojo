// Generated by dojo-bindgen on Mon, 24 Feb 2025 16:27:01 +0000. Do not modify this file manually.
using System;
using Dojo;
using Dojo.Starknet;
using System.Reflection;
using System.Linq;
using System.Collections.Generic;
using Enum = Dojo.Starknet.Enum;
using BigInteger = System.Numerics.BigInteger;


// Model definition for `evolute_duel::models::RoadNode` model
public class evolute_duel_RoadNode : ModelInstance {
    [ModelField("board_id")]
        public FieldElement board_id;

        [ModelField("position")]
        public byte position;

        [ModelField("parent")]
        public byte parent;

        [ModelField("rank")]
        public byte rank;

        [ModelField("blue_points")]
        public ushort blue_points;

        [ModelField("red_points")]
        public ushort red_points;

        [ModelField("open_edges")]
        public byte open_edges;

        [ModelField("contested")]
        public bool contested;

    // Start is called before the first frame update
    void Start() {
    }

    // Update is called once per frame
    void Update() {
    }
}

        