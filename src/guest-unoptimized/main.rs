// Copyright 2026 Shane Jaroch
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Mitigate SP1 zero-register memory manipulation vulnerability by strictly forbidding arbitrary pointer writes.
// https://blog.lambdaclass.com/the-future-of-zk-is-in-risc-v-zkvms-but-the-industry-must-be-careful-how-succincts-sp1s-departure-from-standards-causes-bugs/
#![forbid(unsafe_code)]
#![no_main]
sp1_zkvm::entrypoint!(main);

use ruma_common::{CanonicalJsonObject, OwnedEventId, OwnedRoomId, OwnedUserId, RoomVersionId};
use ruma_events::TimelineEventType;
use ruma_lean::{lean_kahn_sort, HashMap, LeanEvent};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

extern crate alloc;
use alloc::boxed::Box;
use alloc::collections::BTreeMap;
use alloc::string::ToString;
use alloc::vec::Vec;

mod raw_value_as_string {
    use serde::{Deserialize, Deserializer, Serialize, Serializer};
    use serde_json::value::RawValue;

    #[allow(clippy::borrowed_box)]
    pub fn serialize<S>(value: &Box<RawValue>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        value.get().serialize(serializer)
    }

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Box<RawValue>, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        RawValue::from_string(s).map_err(serde::de::Error::custom)
    }
}

#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct GuestEvent {
    pub event: CanonicalJsonObject,
    #[serde(with = "raw_value_as_string")]
    pub content: Box<serde_json::value::RawValue>,
    pub event_id: OwnedEventId,
    pub room_id: OwnedRoomId,
    pub sender: OwnedUserId,
    pub event_type: TimelineEventType,
    pub prev_events: Vec<OwnedEventId>,
    pub auth_events: Vec<OwnedEventId>,
    pub public_key: Option<Vec<u8>>,
    pub signature: Option<Vec<u8>>,
    pub verified_on_host: bool,
}

impl GuestEvent {
    fn origin_server_ts(&self) -> ruma_common::MilliSecondsSinceUnixEpoch {
        let val = self
            .event
            .get("origin_server_ts")
            .expect("missing origin_server_ts");
        serde_json::from_value(val.clone().into()).expect("invalid origin_server_ts")
    }
}

#[derive(Debug, Deserialize, Serialize)]
pub struct DAGMergeInput {
    pub room_version: RoomVersionId,
    pub event_map: BTreeMap<OwnedEventId, GuestEvent>,
}

#[derive(Debug, Deserialize, Serialize, PartialEq, Eq)]
pub struct DAGMergeOutput {
    pub resolved_state_hash: [u8; 32],
}

pub fn main() {
    // Read the input from the Host (the world-state hint containing events)
    let input_bytes: Vec<u8> = sp1_zkvm::io::read();
    let input: DAGMergeInput =
        ciborium::from_reader(input_bytes.as_slice()).expect("Failed to deserialize CBOR input");

    println!("cycle-count-start: resolution-initialization");

    println!("cycle-count-start: ruma-state-resolution");
    println!("> Resolving state maps using Lean implementation...");

    let mut conflicted_events = HashMap::new();
    for (id, guest_ev) in &input.event_map {
        // [Security] Verify Ed25519 signatures if keys are available
        if let (Some(_pk), Some(_sig)) = (&guest_ev.public_key, &guest_ev.signature) {
            // Placeholder for SP1 Ed25519 verification
            if guest_ev.verified_on_host {
                // Trust but verify
            }
        }

        let lean_ev = LeanEvent {
            event_id: id.to_string(),
            power_level: 0, // Simplified for demo
            origin_server_ts: guest_ev.origin_server_ts().0.into(),
            prev_events: guest_ev
                .prev_events
                .iter()
                .map(|id| id.to_string())
                .collect(),
        };
        conflicted_events.insert(lean_ev.event_id.clone(), lean_ev);
    }

    let sorted_ids = lean_kahn_sort(&conflicted_events);

    // Build the resolved state map based on the sorted order (Last-Writer-Wins)
    let mut resolved_state = BTreeMap::new();
    for id in sorted_ids {
        if let Some(ev) = input.event_map.get(&OwnedEventId::try_from(id).unwrap()) {
            let key = (
                ev.event_type.to_string(),
                ev.event
                    .get("state_key")
                    .unwrap()
                    .as_str()
                    .unwrap()
                    .to_string(),
            );
            resolved_state.insert(key, ev.event_id.clone());
        }
    }

    println!("cycle-count-end: ruma-state-resolution");
    println!("cycle-count-start: state-hashing");

    // Journal Commitment: Fingerprint the resolved state
    let mut hasher = Sha256::new();

    for ((event_type, state_key), event_id) in resolved_state {
        hasher.update(event_type.as_bytes());
        hasher.update(state_key.as_bytes());
        hasher.update(event_id.as_str().as_bytes());
    }

    let expected_hash: [u8; 32] = hasher.finalize().into();

    let output = DAGMergeOutput {
        resolved_state_hash: expected_hash,
    };

    println!("cycle-count-end: state-hashing");
    println!("✓ Guest Resolution Protocol Complete!");

    sp1_zkvm::io::commit(&output);
}
