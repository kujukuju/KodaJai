
camera: Camera3;

main :: () {
    koda_init();

    create_window("Window Title", 1600, 900, multisample = 4);

    set_vsync(true);

    model := load_model("tower.glb");
    defer destroy(model);

    camera.position = .{10, 15, 20};
    look_at(*camera, .{0, 8, 0});

    while !koda_should_exit() {
        update_inputs();

        clear(Color.{0.56, 0.88, 0.92, 1.0});

        koda.view = get_transform(camera);

        draw(model);
    }
}

#import "KodaJai";

#import "Basic";
