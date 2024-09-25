
## KodaJai

* Correct handling of edge cases such as windows timing functions and exit scenarios.

* Not an opinionated library. You control draw calls directly. There are helpful things included to optimize batching similar draw calls if you choose to use them.

## Setup

Just `#import "KodaJai";`. 

To bake the assets (into the library) you run `jai ./generate_asset_constants.jai`.

## Notes

The API is constantly changing, and some parts of it are broken. I wouldn't consider this library complete, but the things I currently use work. Which is most things.

## Basic Application

Here's a very basic program, from the tests folder. It just loads and renders a tower.

> EVERYTHING FROM HERE ON IS PROBABLY OUT OF DATE AND I WON'T UPDATE IT UNTIL THE LIBRARY IS MORE FINALIZED

```jai
camera: Camera3;

main :: () {
    koda_init();

    create_window("Window Title", 1600, 900, multisample = 4);

    set_vsync(true);

    model := load_model("tower.glb");
    defer destroy(model);

    camera.position = .{10, 15, 20};
    look_at(*camera, .{0, 8, 0});

    while !should_exit() {
        update_inputs();

        clear(Color.{0.56, 0.88, 0.92, 1.0});

        koda.view = get_transform(camera);

        draw(model);
    }
}

#import "KodaJai";
#import "Basic";
```

I deleted all the documentation for now because it's just wrong and out of date. Read the code.
