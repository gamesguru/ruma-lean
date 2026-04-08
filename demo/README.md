# ZK-Matrix-Join Demo: Instant Trustless Verification

This folder demonstrates the core value proposition of ZK-Matrix-Join: anyone can verify the result of a massive Matrix State Resolution instantly, without downloading the historical event DAG or running the heavy computation themselves.

## 1. The Prover (The Heavy Lifting)

A beefy server or prover node downloads the events, executes the Ruma State Resolution algorithm inside the SP1 zkVM, and generates a succinct STARK proof.

**Command:**

```bash
# Run the prover on 10,000 real Matrix events
# This generates res/proof-with-io.json and res/vk_hash.txt
cargo run --release --bin zk-matrix-join-host
```

## 2. The Verifier (Instant & Trustless)

A light client, a browser, or another homeserver joining the network doesn't need to compute anything. They simply download the tiny STARK proof and mathematically verify it against the guest's Verification Key hash.

**Command:**

```bash
# Instantly verify the computation and extract the resolved state hash
cargo run --release --bin zk-matrix-join-verify
```

### What happens during Verification?

1. **Load Proof:** Loads the STARK proof from `res/proof-with-io.json`.
2. **Load VK:** Loads the Verification Key from `res/vk.bin` (in a production light client, the VK Hash would be hardcoded, and the client would fetch the VK bytes).
3. **Verify Integrity:** Asserts the loaded VK Hash matches the expected `res/vk_hash.txt`.
4. **Verify Math:** Uses the SP1 SDK to mathematically verify the proof instantly without setting up the zkVM execution environment.
5. **Extract State:** Reads the `resolved_state_hash` directly from the validated public values (Journal) of the proof.
