"""Isolated source-preserving enemy/AK bake and FBX animation assembly."""
import bpy,math,json,itertools,sys,hashlib
import numpy as np
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.kdtree import KDTree
r=Path(__file__).resolve().parents[2];job=sys.argv[sys.argv.index('--')+1]
assert job in ('body','ak') and not bpy.data.filepath
out=r/'assets/models/task010';source=r/'assets/source/task010';textures=r/'assets/textures/task010'
for folder in (out,source,textures):folder.mkdir(parents=True,exist_ok=True)
(source/'.gdignore').touch()
def load_mesh(file):
 before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(r/'assets/models'/file))
 obj=next(o for o in set(bpy.data.objects)-before if o.type=='MESH')
 obj.data.transform(obj.matrix_world);obj.parent=None;obj.matrix_world=Matrix.Identity(4)
 return obj
low_file,high_file=('恐怖分子-低模.glb','恐怖分子-高清.glb') if job=='body' else ('AK-47低模.glb','AK-47.glb')
low=load_mesh(low_file);low.name='Low';high=load_mesh(high_file);high.name='High'
lp=np.array([tuple(v.co) for v in low.data.vertices]);hp=np.array([tuple(v.co) for v in high.data.vertices])
lo,hi=lp.min(0),lp.max(0);target=hi-lo;center=(lo+hi)/2
hlo,hhi=hp.min(0),hp.max(0);hc=(hlo+hhi)/2
perm=np.empty(3,dtype=int)
for a,b in zip(np.argsort(target),np.argsort(hhi-hlo)):perm[a]=b
best=None
for signs in itertools.product((-1,1),repeat=3):
 rot=np.zeros((3,3))
 for i in range(3):rot[i,perm[i]]=signs[i]
 if np.linalg.det(rot)<0:continue
 rotated=(hp-hc)@rot.T;scale=target/(rotated.max(0)-rotated.min(0))
 sample=rotated[::max(1,len(rotated)//20000)]*scale+center
 tree=KDTree(len(sample))
 for i,point in enumerate(sample):tree.insert(point,i)
 tree.balance();error=float(np.mean([tree.find(p)[2]**2 for p in lp[::max(1,len(lp)//1200)]]))
 if best is None or error<best[0]:best=(error,rot,scale)
error,rot,scale=best
for vertex,co in zip(high.data.vertices,((hp-hc)@rot.T)*scale+center):vertex.co=co
high.data.update()
print('ALIGNED',job,'rms',math.sqrt(error),flush=True)
if not low.data.uv_layers:low.data.uv_layers.new(name='UV_Baked')
bpy.ops.object.select_all(action='DESELECT');low.select_set(True);bpy.context.view_layer.objects.active=low
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
material=bpy.data.materials.new('Enemy_Cloth_PBR' if job=='body' else 'AK_Wood_Steel_PBR');material.use_nodes=True
low.data.materials.clear();low.data.materials.append(material)
for p in low.data.polygons:p.material_index=0;p.use_smooth=True
bsdf=material.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.72 if job=='body' else .45
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=4
scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=max(target)*.015;scene.render.bake.max_ray_distance=max(target)*.06;scene.render.bake.margin=8
high.select_set(True);images={}
for channel in ('albedo','normal'):
 size=2048 if job=='body' and channel=='albedo' else 1024
 image=bpy.data.images.new(job+'_'+channel,size,size,alpha=False);image.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'
 node=material.node_tree.nodes.new('ShaderNodeTexImage');node.image=image;material.node_tree.nodes.active=node
 records=[]
 if channel=='albedo':
  for mat in high.data.materials:
   if not mat or not mat.use_nodes:continue
   tree=mat.node_tree;principal=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED');output=next(n for n in tree.nodes if n.type=='OUTPUT_MATERIAL')
   old=[(link.from_socket,link.to_socket) for link in output.inputs['Surface'].links];emit=tree.nodes.new('ShaderNodeEmission');socket=principal.inputs['Base Color']
   if socket.links:tree.links.new(socket.links[0].from_socket,emit.inputs['Color'])
   else:emit.inputs['Color'].default_value=socket.default_value
   tree.links.new(emit.outputs[0],output.inputs['Surface']);records.append((tree,emit,old))
 print('BAKE',job,channel,flush=True);bpy.ops.object.bake(type='EMIT' if channel=='albedo' else 'NORMAL')
 for tree,emit,old in records:
  tree.nodes.remove(emit)
  for a,b in old:tree.links.new(a,b)
 image.filepath_raw=str(textures/(job+'_'+channel+'.png'));image.file_format='PNG';image.save();image.pack();images[channel]=image
 if channel=='albedo':material.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
 else:
  normal=material.node_tree.nodes.new('ShaderNodeNormalMap');material.node_tree.links.new(node.outputs['Color'],normal.inputs['Color']);material.node_tree.links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
report={'job':job,'alignment_rms_m':math.sqrt(error),'source_hashes':{f:hashlib.sha256((r/'assets/models'/f).read_bytes()).hexdigest() for f in (low_file,high_file)}}
if job=='ak':
 # Wood remains dielectric; dark receiver/barrel use worn steel response.
 rgb=np.array(images['albedo'].pixels[:]).reshape(-1,4);wood=(rgb[:,0]>rgb[:,2]*1.25)&(rgb[:,0]>rgb[:,1]*1.08)
 metal=bpy.data.images.new('ak_metallic',1024,1024,alpha=False);metal.colorspace_settings.name='Non-Color'
 values=np.ones_like(rgb);values[:,:3]=np.where(wood[:,None],.04,.78);metal.pixels[:]=values.ravel();metal.filepath_raw=str(textures/'ak_metallic.png');metal.file_format='PNG';metal.save();metal.pack()
 node=material.node_tree.nodes.new('ShaderNodeTexImage');node.image=metal;material.node_tree.links.new(node.outputs['Color'],bsdf.inputs['Metallic'])
 lp=np.array([tuple(v.co) for v in low.data.vertices]);lo,hi=lp.min(0),lp.max(0);span=hi-lo
 area=[]
 for side in (-1,1):
  points=lp[lp[:,0]<lo[0]+span[0]*.03] if side<0 else lp[lp[:,0]>hi[0]-span[0]*.03]
  area.append(float(np.ptp(points[:,1])*np.ptp(points[:,2])))
 muzzle_sign=-1 if area[0]<area[1] else 1
 # Blender +Y exports as Godot -Z. Put the pistol grip near the origin.
 scale=.88/span[0];rotation=Matrix.Rotation(muzzle_sign*math.pi/2,4,'Z')
 transform=rotation@Matrix.Scale(scale,4)@Matrix.Translation(Vector(-(lo+hi)/2))
 low.data.transform(transform);low.name='AK47'
 points=np.array([[v.co.x,v.co.z,-v.co.y] for v in low.data.vertices]);report['muzzle']=[float(np.mean(points[points[:,2]<points[:,2].min()+.012,0])),float(np.mean(points[points[:,2]<points[:,2].min()+.012,1])),float(points[:,2].min())]
 report['grip']=[0,-.055,.08]
 bpy.data.objects.remove(high,do_unlink=True);bpy.ops.object.select_all(action='DESELECT');low.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(out/'ak47.glb'),export_format='GLB',use_selection=True,export_apply=True)
else:
 # Keep the delivered rig and transfer only baked material/UV; no auto-rig replacement.
 before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(r/'assets/models/人物战斗动作/Firing Rifle.fbx'))
 base=set(bpy.data.objects)-before;rig=next(o for o in base if o.type=='ARMATURE');meshes=[o for o in base if o.type=='MESH']
 actions={'Fire':rig.animation_data.action.copy()};rig.animation_data.action=None
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 bpy.context.view_layer.update()
 obj=meshes[0];p=np.array([tuple(obj.matrix_world@v.co) for v in obj.data.vertices]);bmin,bmax=p.min(0),p.max(0)
 low.matrix_world=Matrix.Translation(Vector((bmin+bmax)/2))@Matrix.Diagonal((*((bmax-bmin)/target),1))@Matrix.Translation(Vector(-center))
 for obj in meshes:
  bpy.context.view_layer.objects.active=obj;obj.select_set(True)
  if not obj.data.uv_layers:obj.data.uv_layers.new(name='BakedUV')
  transfer=obj.modifiers.new('Baked_source_UV','DATA_TRANSFER');transfer.object=low;transfer.use_loop_data=True;transfer.data_types_loops={'UV'};transfer.loop_mapping='POLYINTERP_NEAREST'
  bpy.ops.object.modifier_apply(modifier=transfer.name);obj.data.materials.clear();obj.data.materials.append(material)
  for poly in obj.data.polygons:poly.material_index=0;poly.use_smooth=True
 for name,file in [('Move','Run Forward.fbx'),('Death','Dying.fbx'),('Crouch','Crouch Rapid Fire.fbx')]:
  before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(r/'assets/models/人物战斗动作'/file));new=set(bpy.data.objects)-before
  other=next(o for o in new if o.type=='ARMATURE');assert set(other.data.bones.keys())==set(rig.data.bones.keys())
  actions[name]=other.animation_data.action.copy()
  for o in new:bpy.data.objects.remove(o,do_unlink=True)
 for track in list(rig.animation_data.nla_tracks):rig.animation_data.nla_tracks.remove(track)
 for name,action in actions.items():
  action.name=name;track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,action)
 rig.animation_data.action=actions['Fire'];scene.frame_set(int(actions['Fire'].frame_range[0]));bpy.context.view_layer.update()
 points=[obj.matrix_world@Vector(corner) for obj in meshes for corner in obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).bound_box]
 height=bmax[2]-bmin[2];factor=1.8/height
 container=bpy.data.objects.new('EnemyFighter',None);scene.collection.objects.link(container)
 for o in base:
  if o.parent not in base:o.parent=container
 container.scale=(factor,)*3;container.location.z=-min(p.z for p in points)*factor
 rig.animation_data.action=None;scene.render.fps=30;scene.frame_set(1)
 for obj in [low,high]:bpy.data.objects.remove(obj,do_unlink=True)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in [container]+list(base):obj.select_set(True)
 bpy.context.view_layer.objects.active=rig
 bpy.ops.export_scene.gltf(filepath=str(out/'enemy_fighter.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False)
 report['clips']=list(actions);report['bones']=list(rig.data.bones.keys());report['scale']=factor
bpy.ops.wm.save_as_mainfile(filepath=str(source/(job+'.blend')))
(r/'logs'/('TASK-010-'+job+'-build.json')).write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf-8')
print('ENEMY_ASSET_READY',job,flush=True)
