# Conventions

## Layering
- models/staging/<source_system>/...: rename/cast/basic cleaning
- models/intermediate/<domain>/...: reusable logic blocks
- models/marts/<domain>/{dims,facts}/...: final analytics outputs

## Naming
- Staging: stg_<source>__<entity>
- Intermediate: int_<domain>__<purpose>
- Dims: dim_<domain>__<entity>
- Facts: fct_<domain>__<process>

## Minimum tests
- PKs: not_null + unique
- Use relationships where you expect FK integrity
- Use accepted_values for enums
