"""Isolated source inspection for the user's new gun, arms and street clutter."""
import bpy
import json
from pathlib import Path
from mathutils import Matrix,Vector
import numpy as np

root=Path(__file__).resolve().parents[2]
assert bpy.data.filepath==''
jobs=[('new_ar','AR-15-1.glb','AR-15-1低模.glb'),('arms','手臂2.glb','手臂2-低模.glb'),
      ('clutter1','杂物1.glb','杂物1-低模.glb'),('clutter2','杂物2.glb','杂物2-低模.glb'),('clutter3','杂物3.glb','杂物3-低模.glb')]
report=[]
for asset,high_file,low_file in jobs:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rows=[]
    objects=[]
    for file,label in ((high_file,'High'),(low_file,'Low')):
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(root/'assets/models'/file))
        obj=next(o for o in bpy.data.objects if o not in before and o.type=='MESH')
        obj.name=label
        obj.data.transform(obj.matrix_world)
        obj.matrix_world=Matrix.Identity(4)
        p=np.array([tuple(v.co) for v in obj.data.vertices])
        minimum,maximum=p.min(axis=0),p.max(axis=0)
        rows.append({'object':label,'file':file,'bounds':[minimum.tolist(),maximum.tolist()],
                     'dimensions':(maximum-minimum).tolist()})
        objects.append(obj)
    directory=root/'assets/source/task009/v003'/asset
    directory.mkdir(parents=True,exist_ok=True)
    (root/'assets/source/task009/v003/.gdignore').touch()
    bpy.ops.wm.save_as_mainfile(filepath=str(directory/'Inspection.blend'))
    row={'asset':asset,'objects':rows}
    report.append(row)
    (root/'logs/TASK-009-v003-source-inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=8
    scene.render.resolution_x,scene.render.resolution_y=900,700
    scene.render.resolution_percentage=100
    world=bpy.data.worlds.new('Inspection_world')
    world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND')
    bg.inputs['Color'].default_value=(.16,.19,.23,1)
    bg.inputs['Strength'].default_value=.8
    scene.world=world
    lamp=bpy.data.lights.new('Key','AREA')
    lamp.shape='DISK'
    light=bpy.data.objects.new('Key',lamp)
    scene.collection.objects.link(light)
    data=bpy.data.cameras.new('Camera')
    camera=bpy.data.objects.new('Camera',data)
    scene.collection.objects.link(camera)
    data.type='ORTHO'
    scene.camera=camera
    for obj,bounds in zip(objects,rows):
        for other in objects: other.hide_render=other!=obj
        minimum,maximum=[Vector(p) for p in bounds['bounds']]
        center=(minimum+maximum)/2
        extent=max(bounds['dimensions'])
        thin=int(np.argmin(bounds['dimensions']))
        direction=Vector((.2,-1,.35)) if thin==1 else Vector((.3,-.4,1))
        if asset.startswith('clutter'): direction=Vector((.8,-1,.75))
        camera.location=center+direction.normalized()*extent*2
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        data.ortho_scale=extent*1.2
        lamp.energy=150*extent*extent
        lamp.size=extent*2
        light.location=center+direction.normalized()*extent*1.7+Vector((0,0,extent*.7))
        light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(root/'logs'/('TASK-009-v003-source-'+asset+'-'+obj.name+'.png'))
        bpy.ops.render.render(write_still=True)
    print('INSPECTED',asset,rows,flush=True)
