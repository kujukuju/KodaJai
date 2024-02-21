
## Deferred Example

### Important Learnings

In general if you're considering something like RGB format, you should just do RGBA since gpus are generally optimized for 4 component strides.

Pretty frequently multiple passes can be combined into 1 pass if you actually franken-solution your way there. This can be a decent performance improvement.
