"""Static, anatomically audited bind pose. Reload stays frozen until this pose is accepted."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
r=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
rig.animation_data_clear()
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4);bone.rotation_mode='QUATERNION'
conv=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def g(v):return conv.inverted()@v
def b(v):return conv@v
frames={};rests={};mapping={'R':'.L_','L':'.R_'}
for side,suffix in mapping.items():
 find=lambda family:next(x for x in rig.data.bones if x.name.startswith(family+suffix))
 hand=rig.data.bones[side+'_Hand'];y=(g(hand.head_local)-g(find('middle_L').head_local)).normalized()
 x=(g(find('index_L').head_local)-g(find('pink_L').head_local)).normalized()*(1 if side=='R' else -1)
 x=(x-y*x.dot(y)).normalized();z=x.cross(y).normalized();frames[side]=Matrix((x,y,z)).transposed()
 rests[side]=[g(rig.data.bones[side+'_'+n].head_local) for n in ('Upper','Forearm','Hand')]
right=Matrix(((0,1,0),(1,0,0),(0,0,-1)))
left=Matrix(((0,-1,0),(0,0,1),(-1,0,0)))
# Each canonical +Z is the black palmar side, verified against source texture, never the yellow dorsal panel.
def pose(side,wrist,canonical):
 joints=rests[side];rotation=canonical@frames[side].inverted();shoulder=Vector((.27,-.28,.35)) if side=='R' else Vector((-.32,-.26,.20))
 l1=(joints[1]-joints[0]).length;l2=(joints[2]-joints[1]).length;direction=wrist-shoulder;d=min(direction.length,l1+l2-.001);direction.normalize();wrist=shoulder+direction*d
 projection=(l1*l1-l2*l2+d*d)/(2*d);pole=Vector((1 if side=='R' else -1,-1,.1));bend=(pole-direction*pole.dot(direction)).normalized();elbow=shoulder+direction*projection+bend*math.sqrt(max(0,l1*l1-projection*projection))
 fore=(rotation@(joints[2]-joints[1])).rotation_difference(wrist-elbow).to_matrix()@rotation
 upper=(fore@(joints[1]-joints[0])).rotation_difference(elbow-shoulder).to_matrix()@fore
 for name,origin,rest,rot in [('Upper',shoulder,joints[0],upper),('Forearm',elbow,joints[1],fore),('Hand',wrist,joints[2],rotation)]:
  bone=rig.pose.bones[side+'_'+name];bone.matrix=Matrix.Translation(b(origin))@(conv@rot@conv.inverted()).to_4x4()@Matrix.Translation(-b(rest))@bone.bone.matrix_local;bpy.context.view_layer.update()
def curl(side):
 axis=b(frames[side].col[0]);suffix=mapping[side]
 for family in ('index_L','middle_L','ring_L','pink_L','thumb_L'):
  bone=next(x for x in rig.pose.bones if x.name.startswith(family+suffix));chain=[]
  while bone:chain.append(bone);bone=next((x for x in bone.children if x.name.startswith(family)),None)
  angles=(.20,.35,.10) if family=='thumb_L' else ((.8,1.0,.6,0) if side=='R' else (1.1,1.3,.6,0))
  if side=='R' and family=='index_L':angles=(.95,.25,.1,0)
  for joint,angle in zip(chain,angles):
   local=joint.bone.matrix_local.to_3x3().inverted()@axis;joint.rotation_quaternion=Quaternion(local.normalized(),-angle)
   if side=='L' and family=='thumb_L' and joint==chain[0]:
    oppose=joint.bone.matrix_local.to_3x3().inverted()@b(frames[side].col[1]);joint.rotation_quaternion=Quaternion(oppose.normalized(),.6)@joint.rotation_quaternion
pose('R',Vector((.065,-.10,.178)),right);pose('L',Vector((-.075,-.005,-.23)),left);curl('R');curl('L');bpy.context.view_layer.update()
# Measure deformation before changing the derivative bind pose.
glove=bpy.data.objects['Object_7'];evaluated=glove.evaluated_get(bpy.context.evaluated_depsgraph_get());posed_mesh=evaluated.to_mesh();edge_excess=max((posed_mesh.vertices[e.vertices[0]].co-posed_mesh.vertices[e.vertices[1]].co).length-(glove.data.vertices[e.vertices[0]].co-glove.data.vertices[e.vertices[1]].co).length for e in glove.data.edges);evaluated.to_mesh_clear()
assert edge_excess<.03, ('Glove webbing overstretch',edge_excess)
# Freeze this posed mesh and skeleton together as the new derivative's bind state.
hand=rig.pose.bones['R_Hand'].matrix.copy();q=(conv.inverted()@hand.to_3x3()@conv).to_quaternion()
palms={side:list(rig.pose.bones[side+'_Hand'].matrix.to_3x3().inverted()@b((right if side=='R' else left).col[2])) for side in mapping}
weights={o.name:hashlib.sha256(str([[(g.group,g.weight) for g in v.groups] for v in o.data.vertices]).encode()).hexdigest() for o in meshes}
for o in meshes:
 bpy.context.view_layer.objects.active=o
 for modifier in list(o.modifiers):
  if modifier.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
 modifier=o.modifiers.new('Static_calibration_skin','ARMATURE');modifier.object=rig
 assert weights[o.name]==hashlib.sha256(str([[(g.group,g.weight) for g in v.groups] for v in o.data.vertices]).encode()).hexdigest()
bpy.context.view_layer.update()
out=r/'assets/models/task009/v006';out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='DESELECT')
for o in [rig]+meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'arms_static.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
directory=r/'assets/source/task009/v006';directory.mkdir(parents=True,exist_ok=True);(directory/'.gdignore').touch();bpy.ops.wm.save_as_mainfile(filepath=str(directory/'Arms_Static.blend'))
report={'model':'res://assets/models/task009/v006/arms_static.glb','source_blend':'res://assets/source/task009/v006/Arms_Static.blend','right_grip_socket':{'position':list(g(hand.translation)),'rotation':[q.x,q.y,q.z,q.w]},'palm_axes':palms,'source_hand_mapping':{'R':'native .L','L':'native .R'},'animations':[],'weight_hashes':weights,'original_weights_preserved':True,'bind_geometry_reposed':True,'prebind_max_edge_length_increase':edge_excess,'raw_sha256':hashlib.sha256((r/'assets/models/hand_with_gloves.glb').read_bytes()).hexdigest()}
(r/'logs/TASK-009-v006-static-build.json').write_text(json.dumps(report,indent=2));print('STATIC_CALIBRATION_EXPORTED',report,flush=True)
