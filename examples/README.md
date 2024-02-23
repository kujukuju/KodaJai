
## Deferred Example

The goal of this is to modularize a bunch of different deferred rendering techniques and in a real game you would merge these into as few as possible render passes.

### Important Learnings

In general if you're considering something like RGB format, you should just do RGBA since gpus are generally optimized for 4 component strides.

Pretty frequently multiple passes can be combined into 1 pass if you actually franken-solution your way there. This can be a decent performance improvement.

You can use textureGather in shadow softening.
