# Phase 3: Module 2 - Local Persistence

## Goal

Build the storage layer that keeps profile and club data available after app restarts.

No UI has been added in this module.

## Scope

- `GolfBagData` snapshot for all local app data.
- `GolfBagStore` storage contract.
- `FileGolfBagStore` JSON-backed local storage adapter.
- `GolfBagRepository` for profile and club operations.
- Repository tests for profile creation, club saving, inactive clubs, deletion, and validation.

## Notes

- The file-backed store is intentionally simple and durable for V1.
- The repository keeps delete and deactivate as separate actions.
- Invalid clubs are rejected before they reach storage.
- The storage contract means a future SwiftData adapter can replace the JSON store without rewriting the screen logic.

