"""Read-only source imports into an isolated .blend, with actual source previews."""
import bpy
import json
from pathlib import Path
from mathutils import Matrix,Vector
import numpy as np

root=Path(__file__).resolve().parents[2]
assert bpy.data.filepath==''
bpy.ops.wm.read_factory_settings(use_empty=True)
report=[]
objects=[]
for name,label in (('AR-15.glb','AR_High'),('AR-15低模.glb','AR_Low')):
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root/'assets/models'/name))
    obj=next(o for o in bpy.data.objects if o not in before and o.type=='MESH')
    obj.name=label
    obj.data.transform(obj.matrix_world)
    obj.matrix_world=Matrix.Identity(4)
    p=np.array([tuple(v.co) for v in obj.data.vertices])
    low,high=p.min(axis=0),p.max(axis=0)
    values,axes=np.linalg.eigh(np.cov(p,rowvar=False))
    report.append({'object':label,'bounds':[low.tolist(),high.tolist()],'dimensions':(high-low).tolist(),
                   'principal_axes':axes.tolist(),'axis_values':values.tolist(),
                   'materials':[m.name for m in obj.data.materials if m],
                   'uv_layers':list(obj.data.uv_layers.keys())})
    objects.append(obj)
folder=root/'assets/source/task009/user_rifle'
folder.mkdir(parents=True,exist_ok=True)
(folder/'.gdignore').touch()
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'AR15_SourceInspection_v001.blend'))
(root/'logs/TASK-009-ar-source-inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=12
scene.render.resolution_x,scene.render.resolution_y=1200,800
scene.render.resolution_percentage=100
world=bpy.data.worlds.new('Inspection_world')
world.use_nodes=True
world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.16,.19,.23,1)
world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.8
scene.world=world
lamp=bpy.data.lights.new('Inspection_key','AREA')
lamp.energy=150
lamp.shape='DISK'
lamp.size=2
light=bpy.data.objects.new('Inspection_key',lamp)
scene.collection.objects.link(light)
camera_data=bpy.data.cameras.new('Inspection_camera')
camera=bpy.data.objects.new('Inspection_camera',camera_data)
scene.collection.objects.link(camera)
camera_data.type='ORTHO'
scene.camera=camera
for obj,row in zip(objects,report):
    for other in objects: other.hide_render=other!=obj
    p=np.array([tuple(v.co) for v in obj.data.vertices])
    center=Vector((p.min(axis=0)+p.max(axis=0))/2)
    extent=float(max(row['dimensions']))
    thin=int(np.argmin(row['dimensions']))
    direction=Vector((.2,-1,.35)) if thin==1 else Vector((.2,.35,1))
    camera.location=center+direction.normalized()*extent*2
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.ortho_scale=extent*1.2
    light.location=center+direction.normalized()*extent*1.7+Vector((0,0,extent*.6))
    light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(root/'logs'/('TASK-009-source-'+obj.name+'.png'))
    bpy.ops.render.render(write_still=True)
print('RIFLE SOURCE INSPECTION',json.dumps(report),flush=True)
