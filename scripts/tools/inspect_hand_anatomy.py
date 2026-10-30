"""Native-bind anatomy inspection; no runtime animation or assumed semantic L/R mapping."""
import bpy,math,json,numpy as np,bmesh
from pathlib import Path
from mathutils import Vector,Matrix
r=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(r/'assets/models/hand_with_gloves.glb'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');glove=bpy.data.objects['Object_7'];sleeve=bpy.data.objects['Object_9']
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
mat=glove.data.materials[0];bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');tex=bsdf.inputs['Base Color'].links[0].from_node.image;pixels=np.array(tex.pixels[:]).reshape(tex.size[1],tex.size[0],4)
reports=[];all_objects=[]
for native,suffix in [('L','.L_'),('R','.R_')]:
 f=lambda prefix:next(b for b in rig.data.bones if b.name.startswith(prefix+suffix))
 hand=f('hand_L');w=rig.matrix_world@hand.head_local
 up=(rig.matrix_world@(f('middle_L').head_local-hand.head_local)).normalized()
 across=(rig.matrix_world@(f('index_L').head_local-f('pink_L').head_local)).normalized();across=(across-up*across.dot(up)).normalized();normal=across.cross(up).normalized()
 group=glove.vertex_groups[hand.name].index;colors={1:[],-1:[]}
 for p in glove.data.polygons:
  weight=sum(sum(g.weight for g in glove.data.vertices[v].groups if g.group==group) for v in p.vertices)/len(p.vertices)
  dot=(glove.matrix_world.to_3x3()@p.normal).normalized().dot(normal)
  if weight>.5 and abs(dot)>.65:
   uv=sum((glove.data.uv_layers.active.data[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
   color=pixels[int(uv.y*tex.size[1])%tex.size[1],int(uv.x*tex.size[0])%tex.size[0],:3]
   colors[1 if dot>0 else -1].append(float(color.mean()))
 brightness={k:float(np.median(v)) for k,v in colors.items()};palm=normal*(1 if brightness[1]<brightness[-1] else -1)
 screen_right=up.cross(palm).normalized();basis=Matrix((screen_right,up,palm)).transposed();target=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
 # target columns are screen-right +X, fingers +Z, palm toward camera -Y.
 transform=(target@basis.inverted()).to_4x4()@Matrix.Diagonal((.03,.03,.03,1))@Matrix.Translation(-w)
 thumb=transform@(rig.matrix_world@f('thumb_L').head_local)
 side='R' if thumb.x>0 else 'L'
 tint=(.65,.035,.025,1) if side=='R' else (.025,.12,.75,1)
 debug=bpy.data.materials.new('Right_red' if side=='R' else 'Left_blue');debug.diffuse_color=tint;debug.use_nodes=True;debug.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=tint
 originals=[]
 for obj in [glove,sleeve]:
  mesh=obj.data.copy();mesh.transform(obj.matrix_world)
  bm=bmesh.new();bm.from_mesh(mesh);remove=[v for v in bm.verts if v.co.x*(1 if native=='L' else -1)<0];bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(mesh);bm.free();mesh.transform(transform)
  if obj==sleeve:mesh.materials.clear();mesh.materials.append(debug)
  for reverse in [False,True]:
   new=mesh.copy();rot=Matrix.Rotation(math.pi if reverse else 0,4,'Z');shift=Matrix.Translation((.17 if reverse else -.17,0,0));new.transform(shift@rot)
   item=bpy.data.objects.new(side+('_back' if reverse else '_palm')+'_'+obj.name,new);bpy.context.scene.collection.objects.link(item);originals.append(item)
 for offset,rotation in [(-.17,0),(.17,math.pi)]:
  for axis,color in [(Vector((1,0,0)),(1,0,0,1)),(Vector((0,1,0)),(0,1,0,1)),(Vector((0,0,1)),(0,0,1,1))]:
   axis=(transform.to_3x3()@rig.matrix_world.to_3x3()@hand.matrix_local.to_3x3()@axis).normalized();axis=Matrix.Rotation(rotation,3,'Z')@axis;start=Vector((offset,-.075,0));end=start+axis*.07
   bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.002,depth=.07,location=(start+end)/2);o=bpy.context.object;o.rotation_euler=(end-start).to_track_quat('Z','Y').to_euler();m=bpy.data.materials.new('axis');m.diffuse_color=color;m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color;o.data.materials.append(m);originals.append(o)
 reports.append({'native_chain':native,'classified_hand':side,'thumb_screen_x_m':thumb.x,'palm_side_median_brightness':brightness,'rest_to_display_determinant':transform.to_3x3().determinant(),'bone_axes_negative_scale':any(b.matrix_local.to_3x3().determinant()<0 for b in rig.data.bones),'animation_disabled':True,'objects':originals})
for o in list(bpy.context.scene.objects):
 if o not in [x for row in reports for x in row['objects']]:bpy.data.objects.remove(o,do_unlink=True)
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=16;s.render.resolution_x=1400;s.render.resolution_y=1100;s.render.resolution_percentage=100;s.world=bpy.data.worlds.new('Anatomy');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.13,.15,.18,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.45
lamp=bpy.data.lights.new('Key','AREA');lamp.energy=35;lamp.size=1;key=bpy.data.objects.new('Key',lamp);s.collection.objects.link(key);key.location=(.2,-.7,.6);key.rotation_euler=(Vector((0,0,.04))-key.location).to_track_quat('-Z','Y').to_euler()
c=bpy.data.cameras.new('Audit_camera');camera=bpy.data.objects.new('Audit_camera',c);s.collection.objects.link(camera);camera.location=(0,-1,.025);camera.rotation_euler=(Vector((0,0,.025))-camera.location).to_track_quat('-Z','Y').to_euler();c.type='ORTHO';c.ortho_scale=.58;s.camera=camera
for row in reports:
 for other in reports:
  for o in other['objects']:o.hide_render=other!=row
 s.render.filepath=str(r/'logs'/('TASK-009-v009-'+('right' if row['classified_hand']=='R' else 'left')+'-hand.png'));bpy.ops.render.render(write_still=True)
for row in reports:del row['objects']
p=r/'assets/source/task009/v009';p.mkdir(parents=True,exist_ok=True);(p/'.gdignore').touch();bpy.ops.wm.save_as_mainfile(filepath=str(p/'Hand_Anatomy.blend'))
(r/'logs/TASK-009-v009-anatomy.json').write_text(json.dumps(reports,indent=2));print('ANATOMY_AUDIT',reports,flush=True)
