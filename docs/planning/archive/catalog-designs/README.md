# Archived Catalog Design Documents

These documents represent the evolution of the Photolala catalog design system. They have been superseded by the final consolidated design in `/docs/planning/photolala-catalog-final-design.md`.

## Archive Contents

1. **catalog-design-considerations.md** - Initial design thoughts and requirements
2. **catalog-delta-handling.md** - Version-based delta system (replaced by hash-based sharding)
3. **catalog-version-delta-design.md** - Intermediate design with numbered deltas
4. **photolala-catalog-design.md** - First full design specification
5. **photolala-catalog-v3-design.md** - V3 iteration with KY's feedback

## Final Design

The final design uses:
- Hash-based sharding (16 shards based on MD5 last hex digit)
- Single delta file per shard (`.delta` suffix)
- Binary plist manifest with shard checksums
- CSV format for catalog data

See `/docs/planning/photolala-catalog-final-design.md` for the current implementation specification.