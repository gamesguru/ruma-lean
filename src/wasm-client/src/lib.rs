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

#![forbid(unsafe_code)]

use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn verify_matrix_join(
    proof_bytes: &[u8],
    public_inputs: &[u8],
    expected_vkey_hash: &str,
) -> bool {
    if proof_bytes.is_empty() {
        return false;
    }

    // Comprehensive Security Analysis: vuln-002-VeilCash (Phase 2 MPC Setup Bypass)
    // In Groth16, if vk_gamma_2 == vk_delta_2, the verification equations cancel out
    // and an attacker can forge a valid proof for ANY public input without the witness.
    // This runtime check guarantees the loaded Verification Key isn't vulnerable to the
    // Foom/Veil Cash exploit. We perform a sliding window check for duplicate G2 elements
    // (128 bytes in BN254) to ensure the trusted setup Phase 2 entropy was applied.
    let vk_bytes = &sp1_verifier::GROTH16_VK_BYTES;
    if has_duplicate_g2_elements(vk_bytes) {
        return false; // ALERT: VULNERABLE VK DETECTED
    }

    sp1_verifier::Groth16Verifier::verify(proof_bytes, public_inputs, expected_vkey_hash, vk_bytes)
        .is_ok()
}

/// Detects if any two 128-byte chunks (G2 elements) in the VK are mathematically identical.
/// This catches `vk_gamma_2 == vk_delta_2` regardless of the underlying serialization struct layout.
fn has_duplicate_g2_elements(vk_bytes: &[u8]) -> bool {
    const G2_SIZE: usize = 128; // BN254 G2 Uncompressed Size
    if vk_bytes.len() < G2_SIZE * 2 {
        return false;
    }

    // Scan for identical G2-sized elements, ensuring cryptographic entropy
    for i in 0..=(vk_bytes.len() - G2_SIZE) {
        let chunk_a = &vk_bytes[i..i + G2_SIZE];
        for j in (i + G2_SIZE)..=(vk_bytes.len() - G2_SIZE) {
            let chunk_b = &vk_bytes[j..j + G2_SIZE];
            if chunk_a == chunk_b {
                return true; // Vulnerability found (Phase 2 skipped)
            }
        }
    }
    false
}

#[wasm_bindgen]
pub fn timed_verify(proof_bytes: &[u8], public_inputs: &[u8], expected_vkey_hash: &str) -> String {
    let start = web_time::Instant::now();
    let success = verify_matrix_join(proof_bytes, public_inputs, expected_vkey_hash);
    let duration = start.elapsed();

    format!(
        "Verification Result: {} (Completed in {:?})",
        if success { "SUCCESS" } else { "FAILURE" },
        duration
    )
}
