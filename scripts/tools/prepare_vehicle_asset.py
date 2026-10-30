"""Normalize user LP/HP copies and bake HP material onto the actual delivered LP.
Run isolated: Blender --background --factory-startup --python this_file.py.
Raw user files are only read, and SHA256 values are recorded before/after.
"""
import bpy
import math
import json
import time
import hashlib
from pathlib import Path
import numpy as np
from mathutils import Vector, Matrix

root = Path(__file__).resolve().parents[2]
raw_low = root/'assets/models/废弃汽车-低模.glb'
raw_high = root/'assets/models/废弃汽车.fbx'
source_dir = root/'assets/source/task008/vehicle'
tex_dir = root/'assets/textures/task008/vehicle'
for directory in (source_dir,tex_dir):
    directory.mkdir(parents=True,exist_ok=True)
assert bpy.data.filepath == '', 'Use factory-startup; never overwrite a user scene.'
hashes = {str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (raw_low,raw_high)}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(raw_high))
high = next(o for o in bpy.context.scene.objects if o.type=='MESH')
high.name = 'Vehicle_High_Source'
bpy.ops.import_scene.gltf(filepath=str(raw_low))
low = next(o for o in bpy.context.scene.objects if o.type=='MESH' and o!=high)
low.name = 'Vehicle_Low_Runtime'
for obj in (high,low):
    obj.data.transform(obj.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
points = np.array([tuple(v.co) for v in low.data.vertices])
values,vectors = np.linalg.eigh(np.cov(points[:,:2],rowvar=False))
long_axis = vectors[:,np.argmax(values)]
if long_axis[1]<0:
    long_axis *= -1
angle = math.atan2(long_axis[0],long_axis[1])
rotation = Matrix.Rotation(angle,4,'Z')
normalization = []
for obj in (high,low):
    obj.data.transform(rotation)
    coordinates = np.array([tuple(v.co) for v in obj.data.vertices])
    lower,upper = coordinates.min(axis=0),coordinates.max(axis=0)
    center = (lower+upper)/2
    center[2] = lower[2]
    scale = np.array([1.8,4.2,1.5])/(upper-lower)
    normalized = (coordinates-center)*scale
    for vertex,co in zip(obj.data.vertices,normalized):
        vertex.co = co
    obj.data.update()
    normalization.append({'object':obj.name,'native_rotated_dimensions':list(upper-lower),'scale':list(scale)})
    for poly in obj.data.polygons:
        poly.use_smooth = True
bpy.context.view_layer.update()

bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active = low
if not low.data.uv_layers:
    low.data.uv_layers.new(name='UV_Baked')
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.02,area_weight=.3)
bpy.ops.object.mode_set(mode='OBJECT')
low.data.materials.clear()
material = bpy.data.materials.new('Vehicle_Baked_PBR')
material.use_nodes = True
low.data.materials.append(material)
bsdf = next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
images = {}
targets = {}
for channel in ('albedo','normal','roughness','metallic'):
    image = bpy.data.images.new('vehicle_'+channel,2048,2048,alpha=False)
    image.colorspace_settings.name = 'sRGB' if channel=='albedo' else 'Non-Color'
    image.filepath_raw = str(tex_dir/('vehicle_'+channel+'_v001.png'))
    image.file_format = 'PNG'
    node = material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image = image
    images[channel],targets[channel] = image,node

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.cycles.device = 'CPU'
scene.render.bake.use_selected_to_active = True
scene.render.bake.cage_extrusion = .025
scene.render.bake.max_ray_distance = .16
scene.render.bake.margin = 12
scene.render.bake.use_clear = True
scene.render.bake.normal_space = 'TANGENT'
high.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low
bake_times = {}

def emission_override(channel):
    records = []
    for mat in high.data.materials:
        if not mat or not mat.node_tree:
            continue
        tree = mat.node_tree
        principal = next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
        output = next(n for n in tree.nodes if n.type=='OUTPUT_MATERIAL')
        previous = [(link.from_socket,link.to_socket) for link in output.inputs['Surface'].links]
        emission = tree.nodes.new('ShaderNodeEmission')
        socket = principal.inputs[{'albedo':'Base Color','roughness':'Roughness','metallic':'Metallic'}[channel]]
        if socket.links:
            tree.links.new(socket.links[0].from_socket,emission.inputs['Color'])
        else:
            value = socket.default_value
            emission.inputs['Color'].default_value = value if channel=='albedo' else (value,value,value,1)
        tree.links.new(emission.outputs[0],output.inputs['Surface'])
        records.append((tree,emission,previous))
    return records

for channel in images:
    started = time.perf_counter()
    material.node_tree.nodes.active = targets[channel]
    records = [] if channel=='normal' else emission_override(channel)
    print('BAKE START',channel,flush=True)
    bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT')
    for tree,emission,previous in records:
        tree.nodes.remove(emission)
        for source,target in previous:
            tree.links.new(source,target)
    images[channel].save()
    images[channel].pack()
    bake_times[channel] = time.perf_counter()-started
    print('BAKE COMPLETE',channel,bake_times[channel],flush=True)

tree = material.node_tree
for channel,input_name in (('albedo','Base Color'),('roughness','Roughness'),('metallic','Metallic')):
    tree.links.new(targets[channel].outputs['Color'],bsdf.inputs[input_name])
normal = tree.nodes.new('ShaderNodeNormalMap')
tree.links.new(targets['normal'].outputs['Color'],normal.inputs['Color'])
tree.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
high.hide_render = True
high.hide_set(True)
# Render inspection established the delivered nose points toward Godot +Z.
# Rotate both prepared copies so the runtime contract is front=-Z.
for obj in (low, high):
    obj.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
    obj.data.update()
bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active = low
output = root/'assets/models/task008/vehicle_final_v001.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_apply=True,
                          export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/'VehicleBake_v001.blend'))
def support_hull(points):
    indices = set()
    for index in range(96):
        z = 1-2*(index+.5)/96
        radius = math.sqrt(1-z*z)
        angle = index*math.pi*(3-math.sqrt(5))
        direction = np.array([radius*math.cos(angle),radius*math.sin(angle),z])
        indices.add(int(np.argmax(points@direction)))
    return [[float(p[0]),float(p[2]),float(-p[1])] for p in points[sorted(indices)]]

runtime_points = np.array([tuple(v.co) for v in low.data.vertices])
hulls = [support_hull(runtime_points[runtime_points[:,2] <= .86]),
         support_hull(runtime_points[runtime_points[:,2] >= .72])]
report = {'source_tool':'Hunyuan3D (confirmed by user)','blender_version':bpy.app.version_string,
          'raw_sha256':hashes,'raw_files_unchanged':all(hashlib.sha256((root/p).read_bytes()).hexdigest()==digest for p,digest in hashes.items()),
          'pca_rotation_degrees':math.degrees(angle),'normalization':normalization,
          'low_triangles':sum(len(p.vertices)-2 for p in low.data.polygons),
          'high_triangles':sum(len(p.vertices)-2 for p in high.data.polygons),
          'runtime_dimensions_godot':[1.8,1.5,4.2], 'uv_layers':list(low.data.uv_layers.keys()),
          'texture_size':[2048,2048],'bake_seconds':bake_times,'runtime_glb':str(output.relative_to(root)),
          'runtime_bytes':output.stat().st_size,'source_blend':str((source_dir/'VehicleBake_v001.blend').relative_to(root)),
          'license':'User-supplied Hunyuan3D output; usage terms not provided; local sample evaluation',
          'collision_hulls':hulls, 'front_axis_godot':'-Z', 'front_axis_corrected':True}
(root/'logs/TASK-008-vehicle-bake-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print('VEHICLE PREPARE COMPLETE',json.dumps(report,ensure_ascii=False),flush=True)
