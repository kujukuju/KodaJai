
## Baked Shadow Volumes

### Precursory

1. for every object in the scene I need to find all faces facing away from the light

2. or rather I should get all the faces, period. and then only allow shadows to be cast on faces that are facing towards the light
   
   this would allow even light facing non-volume faces to project shadows

3. I need to flatten every single triangle in the scene, I guess, into a 2d surface of all the triangles

4. if I'm being really tryhard I could use a potential occlusion texture to generate approximate edges for some objects

   I think this could maybe go wrong between edges of triangles that share the occlusion texture since you might be sampling different pixels, but maybe if you do a linear sample exactly like opengl its fine

5. I need to go through and resolve all the intersections of every 2d triangle to form multiple giant concave meshes

### Geometry application

6. for every triangle in the scene, I need go to through and find it's intersection(s) with the projected mesh

7. the resulting intersection(s) for each scene triangle need to be stored

8. these triangles need to be merged by vertex distances and resolved/reduced because you don't need normals for this data

### Stencil application

6. convert all your 2d concave meshes to 3d concave meshes (projected onto the light view plane)

7. reduce your 3d concave meshes to just edges, no triangle data

### Stencil application (normal stencil extruding)

8. in your engine extrude these edges as you would a normal shadow meshes in a geometry shader, and render twice (back/front) with depth testing to increment/decrement the pass/fail values

### Stencil applcation (baked extrusion)

8. manually extrude your 3d concave lines to create actual 3d shadow volumes, and skip the geometry shader step
