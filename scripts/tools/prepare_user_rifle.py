"""User AR-15 derived low-poly preparation; source inspection .blend is read-only."""
import bpy
import bmesh
import math
import json
import hashlib
from pathlib import Path
from mathutils import Matrix,Vector
import numpy as np

root=Path(__file__).resolve().parents[2]
assert bpy.data.filepath==''
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/source/task009/user_rifle/AR15_SourceInspection_v001.blend'))
high=bpy.data.objects['AR_High']
low=bpy.data.objects['AR_Low']
for obj in (high,low):
    points=np.array([tuple(v.co) for v in obj.data.vertices])
    minimum,maximum=points.min(axis=0),points.max(axis=0)
    center=(minimum+maximum)/2
    scale=.93/(maximum[0]-minimum[0])
    obj.data.transform(Matrix.Rotation(-math.pi/2,4,'Z') @ Matrix.Scale(scale,4) @ Matrix.Translation(Vector(-center)))
    obj.data.update()
    obj.hide_render=False
    obj.hide_set(False)
points=np.array([[v.co.x,v.co.z,-v.co.y] for v in low.data.vertices])
diagnostic={'bounds_godot':[points.min(axis=0).tolist(),points.max(axis=0).tolist()]}
for name,mask in [('optic', (points[:,1]>.08)&(points[:,2]>-.15)&(points[:,2]<.15)),
                  ('magazine',(points[:,1]<-.06)&(points[:,2]<.08)&(points[:,2]>-.16))]:
    selected=points[mask]
    diagnostic[name]={'bounds':[selected.min(axis=0).tolist(),selected.max(axis=0).tolist()],
                      'points':selected.round(4).tolist()}
(root/'logs/TASK-009-ar-normalized-points.json').write_text(json.dumps(diagnostic,indent=2),encoding='utf-8')
print('NORMALIZED DIAGNOSTIC',{k:v['bounds'] if 'bounds' in v else v for k,v in diagnostic.items()},flush=True)

folder=root/'assets/source/task009/user_rifle'
texture_dir=root/'assets/textures/task009/user_ar15'
texture_dir.mkdir(parents=True,exist_ok=True)
raw_files=[root/'assets/models'/name for name in ('AR-15低模.glb','AR-15.glb')]
hashes={p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in raw_files}
bpy.ops.object.select_all(action='DESELECT')
low.select_set(True)
bpy.context.view_layer.objects.active=low
for polygon in low.data.polygons:
    polygon.use_smooth=True
low.data.uv_layers.new(name='UV_Baked')
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015,area_weight=.25)
bpy.ops.object.mode_set(mode='OBJECT')
low.data.materials.clear()
material=bpy.data.materials.new('User_AR15_Baked_PBR')
material.use_nodes=True
low.data.materials.append(material)
bsdf=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
images,targets={},{}
for channel in ('albedo','normal','roughness','metallic'):
    image=bpy.data.images.new('user_ar15_'+channel,2048,2048,alpha=False)
    image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'
    image.filepath_raw=str(texture_dir/('ar15_'+channel+'_v001.png'))
    image.file_format='PNG'
    node=material.node_tree.nodes.new('ShaderNodeTexImage')
    node.image=image
    images[channel],targets[channel]=image,node
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=8
scene.render.bake.use_selected_to_active=True
scene.render.bake.cage_extrusion=.006
scene.render.bake.max_ray_distance=.03
scene.render.bake.margin=12
scene.render.bake.normal_space='TANGENT'
high.select_set(True)
for channel in images:
    material.node_tree.nodes.active=targets[channel]
    records=[]
    if channel!='normal':
        for mat in high.data.materials:
            tree=mat.node_tree
            principal=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
            output=next(n for n in tree.nodes if n.type=='OUTPUT_MATERIAL')
            old=[(link.from_socket,link.to_socket) for link in output.inputs['Surface'].links]
            emission=tree.nodes.new('ShaderNodeEmission')
            socket=principal.inputs[{'albedo':'Base Color','roughness':'Roughness','metallic':'Metallic'}[channel]]
            if socket.links:
                tree.links.new(socket.links[0].from_socket,emission.inputs['Color'])
            else:
                value=socket.default_value
                emission.inputs['Color'].default_value=value if channel=='albedo' else (value,value,value,1)
            tree.links.new(emission.outputs[0],output.inputs['Surface'])
            records.append((tree,emission,old))
    print('USER AR BAKE',channel,flush=True)
    bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT')
    for tree,node,old in records:
        tree.nodes.remove(node)
        for a,b in old: tree.links.new(a,b)
    images[channel].save()
    images[channel].pack()
for channel,input_name in (('albedo','Base Color'),('roughness','Roughness'),('metallic','Metallic')):
    material.node_tree.links.new(targets[channel].outputs['Color'],bsdf.inputs[input_name])
normal=material.node_tree.nodes.new('ShaderNodeNormalMap')
material.node_tree.links.new(targets['normal'].outputs['Color'],normal.inputs['Color'])
material.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])

def boolean(obj,cutter,operation):
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Derived_component_cut','BOOLEAN')
    modifier.operation=operation
    modifier.solver='EXACT'
    modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)

# Cut below the magazine well while keeping the pistol grip and trigger separate.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.18))
cutter=bpy.context.object
cutter.name='Magazine_cut_volume'
cutter.dimensions=(.15,.16,.25)  # Godot Z ±.08, Y <= -.055
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
magazine=low.copy()
magazine.data=low.data.copy()
bpy.context.scene.collection.objects.link(magazine)
boolean(magazine,cutter,'INTERSECT')
boolean(low,cutter,'DIFFERENCE')
bpy.data.objects.remove(cutter,do_unlink=True)
magazine.name='Magazine'
low.name='Rifle_Body'

# Open the opaque optic along its real longitudinal axis, then insert a clear disc.
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.019,depth=.22,location=(-.0043,-.03,.15),rotation=(math.pi/2,0,0))
cutter=bpy.context.object
cutter.name='Optic_bore_cut'
boolean(low,cutter,'DIFFERENCE')
bpy.data.objects.remove(cutter,do_unlink=True)
dark=bpy.data.materials.new('Dark_component_interfaces')
dark.use_nodes=True
dark_bsdf=next(n for n in dark.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
dark_bsdf.inputs['Base Color'].default_value=(.015,.018,.02,1)
dark_bsdf.inputs['Metallic'].default_value=.5
dark_bsdf.inputs['Roughness'].default_value=.7
for obj in (low,magazine):
    dark_index=len(obj.data.materials)
    obj.data.materials.append(dark)
    for polygon in obj.data.polygons:
        if obj.data.materials[polygon.material_index] is None or abs(polygon.center.z+.055)<.0003:
            polygon.material_index=dark_index
bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=.0188,depth=.0007,location=(-.0043,-.112,.15),rotation=(math.pi/2,0,0))
glass=bpy.context.object
glass.name='Optic_Glass'
glass_material=bpy.data.materials.new('Coated_optic_glass')
glass_material.use_nodes=True
glass_bsdf=next(n for n in glass_material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
glass_bsdf.inputs['Base Color'].default_value=(.18,.3,.34,1)
glass_bsdf.inputs['Alpha'].default_value=.08
glass_bsdf.inputs['Roughness'].default_value=.08
glass.data.materials.append(glass_material)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)

# Align the optic's rear lens to the existing calibrated ADS mount.
translation=Vector((.0043,.07,-.015))  # Blender: Godot (.0043,-.015,-.07)
for obj in (low,magazine,high):
    obj.data.transform(Matrix.Translation(translation))
glass.location+=translation
front=points[points[:,2]<-.445]
muzzle=[float((front[:,0].min()+front[:,0].max())/2+.0043),
        float((front[:,1].min()+front[:,1].max())/2-.015),-.536]
high.hide_render=True
high.hide_set(True)
bpy.ops.object.select_all(action='DESELECT')
for obj in (low,magazine,glass): obj.select_set(True)
bpy.context.view_layer.objects.active=low
output=root/'assets/models/task009/user_ar15_v002.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_apply=True,
                          export_yup=True,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'AR15_Prepared_v002.blend'))
report={'source_tool':'Hunyuan3D, confirmed by user','runtime_glb':output.relative_to(root).as_posix(),
        'source_blend':(folder/'AR15_Prepared_v002.blend').relative_to(root).as_posix(),
        'raw_sha256':hashes,'raw_files_unchanged':all(hashlib.sha256((root/p).read_bytes()).hexdigest()==h for p,h in hashes.items()),
        'components':{o.name:sum(len(p.vertices)-2 for p in o.data.polygons) for o in (low,magazine,glass)},
        'muzzle_godot':muzzle,'sight_center_godot':[0,.135,.042],'texture_size':[2048,2048],
        'scope_bore_radius':.019,'license':'User-supplied Hunyuan3D output; terms not supplied; local evaluation'}
(root/'logs/TASK-009-user-ar15-bake-audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('USER AR PREPARED',json.dumps(report),flush=True)
