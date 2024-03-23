
InstancedModelGpu :: struct {
    m1: Vector4;
    m2: Vector4;
    m3: Vector4;
    m4: Vector4;
#place m1;
    model: Matrix4 = ---;
}

InstancedModel :: GenericInstancedModel(InstancedModelGpu);

create_instanced_model :: (geometry: *Geometry) -> *InstancedModel {
    model := create_instanced_model(geometry, dynamic = true);
    return model;
}

create_instanced_model :: (geometry: *Geometry, instances: [] InstancedModelGpu) -> *InstancedModel {
    model := create_instanced_model(geometry, dynamic = false);
    set_instances(model, instances);
    return model;
}

create_instanced_model :: (geometry: *Geometry, dynamic: bool) -> *InstancedModel {
    model := New(InstancedModel);
    init_instanced_model(model, geometry, dynamic);
    return model;
}

set_instances :: (model: *InstancedModel, instances: [] Matrix4) {
    instanced_gpu: [] InstancedModelGpu;
    instanced_gpu.data = cast(*InstancedModelGpu) instances.data;
    instanced_gpu.count = instances.count;

    set_instances(model, instanced_gpu);
}
