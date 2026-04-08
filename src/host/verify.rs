use serde::{Deserialize, Serialize};
use sp1_sdk::blocking::{Prover, ProverClient};
use sp1_sdk::{HashableKey, SP1ProofWithPublicValues, SP1VerifyingKey};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DAGMergeOutput {
    pub resolved_state_hash: [u8; 32],
}

fn main() {
    let proof_path = "res/proof-with-io.json";
    let vk_hash_path = "res/vk_hash.txt";
    let vk_bin_path = "res/vk.bin";

    println!("> Loading SP1 STARK Proof from {}...", proof_path);
    let mut proof = SP1ProofWithPublicValues::load(proof_path).expect("Failed to load proof");

    println!("> Loading Verification Key from {}...", vk_bin_path);
    let vk_bytes = std::fs::read(vk_bin_path).expect("Failed to read vk.bin");
    let vk: SP1VerifyingKey = bincode::deserialize(&vk_bytes).expect("Failed to deserialize VK");

    let actual_vk_hash = vk.bytes32();
    let expected_vk_hash = std::fs::read_to_string(vk_hash_path)
        .unwrap_or_default()
        .trim()
        .to_string();

    println!("  [vk] Expected: {}", expected_vk_hash);
    println!("  [vk] Computed: {}", actual_vk_hash);

    if actual_vk_hash != expected_vk_hash && !expected_vk_hash.is_empty() {
        panic!("Verification Key Hash Mismatch! The ELF binary has been altered.");
    }

    println!("> Verifying STARK Proof for Matrix State Resolution...");
    let prover_client = ProverClient::from_env();
    prover_client
        .verify(&proof, &vk, None)
        .expect("STARK Proof Verification Failed!");

    let output: DAGMergeOutput = proof.public_values.read();
    println!("--------------------------------------------------");
    println!("✓ Cryptographic Proof Mathematically Verified!");
    println!(
        "Matrix Resolved State Hash (Journal): {:?}",
        hex::encode(output.resolved_state_hash)
    );
    println!("(See `res/resolved_state.json` for the full event state mapping.)");
}
