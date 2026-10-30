"""Bake the delivered low meshes in isolated processes, keeping all raw files unchanged."""
import bpy
import json
import math
import sys
import hashlib
from pathlib import Path
from mathutils import Matrix,Vector
import numpy as np

root=Path(__file__).resolve().parents[2]
asset=sys.argv[sys.argv.index('--')+1]
assert asset in ('new_ar','arms','clutter1','clutter2','clutter3')
assert bpy.data.filepath==''
directory=root/'assets/source/task009/v003'/asset
bpy.ops.wm.open_mainfile(filepath=str(directory/'Inspection.blend'))
high,low=bpy.data.objects['High'],bpy.data.objects['Low']
inspection=json.loads((root/'logs/TASK-009-v003-source-inspection.json').read_text())
record=next(r for r in inspection if r['asset']==asset)
hashes={r['file']:hashlib.sha256((root/'assets/models'/r['file']).read_bytes()).hexdigest() for r in record['objects']}
points=np.array([tuple(v.co) for v in low.data.vertices])
minimum,maximum=points.min(axis=0),points.max(axis=0)
target=maximum-minimum
angle=0.0
if asset=='new_ar':
    end_sizes=[]
    for end in (0,1):
        end_points=points[points[:,1]<(minimum[1]+target[1]*.025)] if end==0 else points[points[:,1]>(maximum[1]-target[1]*.025)]
        end_sizes.append(float(np.ptp(end_points[:,0])*np.ptp(end_points[:,2])))
    angle=math.pi if end_sizes[0]<end_sizes[1] else 0
    target*=.93/target[1]
elif asset=='arms':
    target*=.82/target[2]
else:
    target*=2/max(target[0],target[1])
for obj in (high,low):
    p=np.array([tuple(v.co) for v in obj.data.vertices])
    lo,hi=p.min(axis=0),p.max(axis=0)
    center=(hi+lo)/2
    if asset!='new_ar': center[2]=lo[2]
    q=(p-center)*(target/(hi-lo))
    for vertex,co in zip(obj.data.vertices,q): vertex.co=co
    obj.data.transform(Matrix.Rotation(angle,4,'Z'))
    obj.data.update()
    obj.hide_render=False
    obj.hide_set(False)
bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active=low
low.data.uv_layers.new(name='UV_Baked')
for polygon in low.data.polygons: polygon.use_smooth=True
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015,area_weight=.25)
bpy.ops.object.mode_set(mode='OBJECT')
low.data.materials.clear()
material=bpy.data.materials.new(asset+'_Baked_PBR')
material.use_nodes=True
low.data.materials.append(material)
principal=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
images,nodes={},{}
texture_dir=root/'assets/textures/task009/v003'/asset
texture_dir.mkdir(parents=True,exist_ok=True)
for channel in ('albedo','normal','roughness','metallic'):
    image=bpy.data.images.new(asset+'_'+channel,2048,2048,alpha=False)
    image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'
    image.filepath_raw=str(texture_dir/(channel+'.png'))
    image.file_format='PNG'
    node=material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=image
    images[channel],nodes[channel]=image,node
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=8
scene.render.bake.use_selected_to_active=True
scene.render.bake.cage_extrusion=.006 if asset=='new_ar' else .012
scene.render.bake.max_ray_distance=.03 if asset=='new_ar' else .07
scene.render.bake.margin=12
scene.render.bake.normal_space='TANGENT'
high.select_set(True)
for channel,image in images.items():
    material.node_tree.nodes.active=nodes[channel]
    old=[]
    if channel!='normal':
        for mat in high.data.materials:
            tree=mat.node_tree
            bsdf=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
            output=next(n for n in tree.nodes if n.type=='OUTPUT_MATERIAL')
            previous=[(l.from_socket,l.to_socket) for l in output.inputs['Surface'].links]
            emission=tree.nodes.new('ShaderNodeEmission')
            socket=bsdf.inputs[{'albedo':'Base Color','roughness':'Roughness','metallic':'Metallic'}[channel]]
            if socket.links: tree.links.new(socket.links[0].from_socket,emission.inputs['Color'])
            else:
                value=socket.default_value
                emission.inputs['Color'].default_value=value if channel=='albedo' else (value,value,value,1)
            tree.links.new(emission.outputs[0],output.inputs['Surface'])
            old.append((tree,emission,previous))
    print('BAKE',asset,channel,flush=True)
    bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT')
    for tree,emission,previous in old:
        tree.nodes.remove(emission)
        for a,b in previous: tree.links.new(a,b)
    if asset=='arms' and channel in ('roughness','metallic'):
        pixels=np.empty(2048*2048*4,dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels=pixels.reshape((-1,4))
        pixels[:,:3]=np.maximum(pixels[:,:3],.55) if channel=='roughness' else 0
        image.pixels.foreach_set(pixels.ravel())
    image.save()
    image.pack()
for channel,target_name in (('albedo','Base Color'),('roughness','Roughness'),('metallic','Metallic')):
    material.node_tree.links.new(nodes[channel].outputs['Color'],principal.inputs[target_name])
normal=material.node_tree.nodes.new('ShaderNodeNormalMap')
material.node_tree.links.new(nodes['normal'].outputs['Color'],normal.inputs['Color'])
material.node_tree.links.new(normal.outputs['Normal'],principal.inputs['Normal'])
high.hide_render=True
high.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active=low
low.name=asset+'_Low'
bpy.ops.wm.save_as_mainfile(filepath=str(directory/'Baked.blend'))
out=root/'assets/models/task009/v003'
out.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(out/(asset+'_base.glb')),export_format='GLB',use_selection=True,
                          export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
report={'asset':asset,'raw_sha256':hashes,'raw_files_unchanged':all(hashlib.sha256((root/'assets/models'/p).read_bytes()).hexdigest()==h for p,h in hashes.items()),
        'rotation_degrees':math.degrees(angle),'target_dimensions_blender':target.tolist(),
        'triangles':sum(len(p.vertices)-2 for p in low.data.polygons),'texture_resolution':[2048,2048],
        'skin_adjustment':'roughness min .55 and metallic zero' if asset=='arms' else None}
(root/'logs'/('TASK-009-v003-bake-'+asset+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('BAKED',asset,report,flush=True)
