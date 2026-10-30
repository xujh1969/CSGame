"""Non-destructive MCP review assembly; preserves all pre-existing scenes/objects."""
import bpy
import math
from pathlib import Path
from mathutils import Vector

root = Path(r'C:\Users\AYOU\Desktop\CS')
review_name = 'TASK008_Street_Review_v003'
existing = bpy.data.scenes.get(review_name)
assert existing is None or len(existing.objects) == 0, 'Review scene already exists; inspect it rather than duplicate.'
source = root/'assets/source/task008/StreetKit_v002.blend'
with bpy.data.libraries.load(str(source), link=False) as (available, loaded):
    requested_names = [n for n in available.collections if n.endswith(('_v001','_v002'))]
    loaded.collections = requested_names.copy()
collections = dict(zip(requested_names, loaded.collections))
review = existing if existing is not None else bpy.data.scenes.new(review_name)
review.unit_settings.system = 'METRIC'
review.unit_settings.scale_length = 1

def instance(name, collection, pos=(0,0,0), yaw=0):
    obj = bpy.data.objects.new(name, None)
    obj.instance_type = 'COLLECTION'
    obj.instance_collection = collections[collection]
    obj.location = (pos[0],-pos[2],pos[1])
    obj.rotation_euler.z = yaw
    review.collection.objects.link(obj)
    return obj

for z in (-2,-10,-18):
    instance('Residential_%d' % -z, 'residential_v002', (6,0,z), -math.pi/2)
    instance('Shop_%d' % -z, 'shopfront_v001', (-6,0,z), math.pi/2)
instance('Road','road_v001')
instance('Barrier','barrier_v001',(-2,0,-9))
instance('Crates','crates_v001',(3.8,0,-5.5))
instance('Details','street_details_v002')
vehicle_source = root/'assets/source/task008/vehicle/VehicleBake_v001.blend'
with bpy.data.libraries.load(str(vehicle_source), link=False) as (available, loaded):
    loaded.objects = ['Vehicle_Low_Runtime']
vehicle = loaded.objects[0]
review.collection.objects.link(vehicle)
vehicle.location = (-3.35,15,0)
vehicle.rotation_euler.z = -.15
vehicle.hide_render = False
camera_data = bpy.data.cameras.new('TASK008_Camera')
camera = bpy.data.objects.new('TASK008_Camera',camera_data)
review.collection.objects.link(camera)
camera.location = (0,-3,1.7)
target = Vector((0,22,2.7))
camera.rotation_euler = (target-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.sensor_fit = 'VERTICAL'
camera_data.sensor_height = 24
camera_data.lens = 24/(2*math.tan(math.radians(75/2)))
review.camera = camera
sun_data = bpy.data.lights.new('TASK008_Sun','SUN')
sun_data.energy = 2.0
sun_data.color = (1,.86,.68)
sun = bpy.data.objects.new('TASK008_Sun',sun_data)
sun.rotation_euler = (math.radians(38),math.radians(-20),math.radians(-48))
review.collection.objects.link(sun)
world = bpy.data.worlds.new('TASK008_World')
world.use_nodes = True
background = next((n for n in world.node_tree.nodes if n.type=='BACKGROUND'),None)
if background is None:
    background = world.node_tree.nodes.new('ShaderNodeBackground')
output_node = next((n for n in world.node_tree.nodes if n.type=='OUTPUT_WORLD'),None)
if output_node is None:
    output_node = world.node_tree.nodes.new('ShaderNodeOutputWorld')
world.node_tree.links.new(background.outputs[0],output_node.inputs['Surface'])
background.inputs['Color'].default_value = (.45,.55,.65,1)
background.inputs['Strength'].default_value = .5
review.world = world
review.render.engine = 'CYCLES'
review.cycles.samples = 16
review.render.resolution_x,review.render.resolution_y = 1280,720
review.render.resolution_percentage = 100
if bpy.context.window:
    bpy.context.window.scene = review
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
output = root/'assets/source/task008/StreetReview_v003.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(output))
result = {'review_file':str(output), 'scene': review.name,
          'preserved_scenes':[s.name for s in bpy.data.scenes if s != review],
          'collection_modules':list(collections), 'review_objects':len(review.objects),
          'missing_images':[i.filepath for i in bpy.data.images if i.source=='FILE' and not i.packed_file and not Path(bpy.path.abspath(i.filepath)).exists()]}
