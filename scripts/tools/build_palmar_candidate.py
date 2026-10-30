"""Solve a new diagnostic-only rig from measured palmar markers, not wrist guesses."""
import bpy,json,hashlib,math,sys
sys.path.insert(0,str(__import__("pathlib").Path(__file__).resolve().parent))
from fit_foregrip_fingers import fit_left
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
r=Path(__file__).resolve().parents[2];cal=json.loads((r/'logs/TASK-009-palmar-calibration-native.json').read_text())
assert cal['source_glb_sha256']==hashlib.sha256((r/'assets/models/task009/v005/gloves_rigged.glb').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];rig.animation_data_clear()
# v005 semantic names were reversed. Swap semantic bones and their actual vertex groups,
# preserving group indices/weights and native finger names. No reflection or negative scale.
def corrected_name(name):
 return ('L_'+name[2:]) if name.startswith('R_') else (('R_'+name[2:]) if name.startswith('L_') else name)
bones=[(bone,bone.name) for bone in rig.data.bones if bone.name.startswith(('R_','L_'))]
groups=[(obj,[(group.index,group.name) for group in obj.vertex_groups]) for obj in meshes]
for bone,name in bones:bone.name='SWAP_'+name
for bone,name in bones:bone.name=corrected_name(name)
for obj,names in groups:
 for index,name in names:obj.vertex_groups[index].name='SWAP_GROUP_'+str(index)
 for index,name in names:obj.vertex_groups[index].name=corrected_name(name)
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4);bone.rotation_mode='QUATERNION'
C=Matrix(((1,0,0),(0,0,1),(0,-1,0))).to_4x4()
def matrix(data):
 m=Matrix(data['basis']).transposed().to_4x4();m.translation=Vector(data['origin']);return m
def local_marker(data):return matrix({'basis':data['bone_local_basis'],'origin':data['bone_local_position']})
def blender(v):return C.inverted()@Vector(v)
report={'method':'Hand_target = desired_palmar_socket * inverse(actual_palmar_marker)','source_glb_sha256':cal['source_glb_sha256'],'hands':{},'animations':[],'source_hand_mapping':{'R':'native .R','L':'native .L'},'correction':'v005 semantic bones and skin groups swapped together; native geometry unchanged','original_weights_preserved':True}
for side,key,suffix in [('R','left_grip','.R_'),('L','right_grip','.L_')]:
 data=dict(cal[key]);data['desired_socket']=cal['right_grip' if side=='R' else 'left_grip']['desired_socket'];rest_hand=rig.data.bones[side+'_Hand'].matrix_local.copy();g_bind=matrix(data['hand_bind_frame']);correction=(C@rest_hand).inverted()@g_bind
 assert correction.translation.length<.0001,(side,'bind translation mismatch',list(correction.translation))
 target_g=matrix(data['desired_socket'])@local_marker(data).inverted();target=C.inverted()@target_g@correction.inverted()
 joints=[rig.data.bones[side+'_'+n].head_local.copy() for n in ('Upper','Forearm','Hand')]
 shoulder=blender((.27,-.28,.35) if side=='R' else (-.32,-.26,.20));wrist=target.translation
 l1=(joints[1]-joints[0]).length;l2=(joints[2]-joints[1]).length;direction=wrist-shoulder;distance=direction.length
 assert abs(l1-l2)<distance<l1+l2,(side,'calibrated palm is unreachable',distance,l1+l2)
 direction.normalize();projection=(l1*l1-l2*l2+distance*distance)/(2*distance);pole=blender((1 if side=='R' else -1,-1,.1));bend=(pole-direction*pole.dot(direction)).normalized();elbow=shoulder+direction*projection+bend*math.sqrt(max(0,l1*l1-projection*projection))
 hand_delta=target.to_3x3()@rest_hand.to_3x3().inverted()
 fore=(hand_delta@(joints[2]-joints[1])).rotation_difference(wrist-elbow).to_matrix()@hand_delta
 upper=(fore@(joints[1]-joints[0])).rotation_difference(elbow-shoulder).to_matrix()@fore
 for name,head,rest,rotation in [('Upper',shoulder,joints[0],upper),('Forearm',elbow,joints[1],fore)]:
  bone=rig.pose.bones[side+'_'+name];bone.matrix=Matrix.Translation(head)@rotation.to_4x4()@Matrix.Translation(-rest)@bone.bone.matrix_local;bpy.context.view_layer.update()
 rig.pose.bones[side+'_Hand'].matrix=target;bpy.context.view_layer.update()
 palm_rest=(rest_hand@correction).to_3x3()@Vector(data['bone_local_basis'][2]);palm_rest.normalize()
 for family in ('index_L','middle_L','ring_L','pink_L','thumb_L'):
  bone=next(b for b in rig.pose.bones if b.name.startswith(family+suffix));chain=[]
  while bone:chain.append(bone);bone=next((b for b in bone.children if b.name.startswith(family)),None)
  angles=(.15,.30,0) if family=='thumb_L' else ((.6,.9,.45,0) if side=='R' else (.5,.8,.35,0))
  if side=='R' and family=='index_L':angles=(.35,.45,.2,0)
  for i,(bone,angle) in enumerate(zip(chain,angles)):
   if angle==0:continue
   direction=chain[i+1].bone.head_local-bone.bone.head_local if i+1<len(chain) else bone.bone.tail_local-bone.bone.head_local
   axis=direction.normalized().cross(palm_rest).normalized()
   local=bone.bone.matrix_local.to_3x3().inverted()@axis;bone.rotation_quaternion=Quaternion(local.normalized(),angle)
 if side=='L':report['finger_surface_fit']=fit_left(rig,C,r,palm_rest)
 report['hands'][side]={'target_bone_godot':{'origin':list(target_g.translation),'basis':[list(target_g.to_3x3().col[i]) for i in range(3)]},'joint_frame_correction':[list(row) for row in correction],'palmar_calibration':data}
bpy.context.view_layer.update();glove=bpy.data.objects['Object_7'];e=glove.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();excess=max((m.vertices[x.vertices[0]].co-m.vertices[x.vertices[1]].co).length-(glove.data.vertices[x.vertices[0]].co-glove.data.vertices[x.vertices[1]].co).length for x in glove.data.edges);bad_edges=sorted([{'increase':(m.vertices[x.vertices[0]].co-m.vertices[x.vertices[1]].co).length-(glove.data.vertices[x.vertices[0]].co-glove.data.vertices[x.vertices[1]].co).length,'weights':[[[glove.vertex_groups[g.group].name,g.weight] for g in glove.data.vertices[i].groups if g.weight>.1] for i in x.vertices]} for x in glove.data.edges],key=lambda x:x['increase'],reverse=True)[:5]
e.to_mesh_clear();report['prebind_max_edge_length_increase']=excess;report['edge_audit']=bad_edges
(r/'logs/TASK-009-v009-grip-build-attempt.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
assert excess<.03,('glove webbing overstretch',excess)
weights={o.name:str([[(g.group,g.weight) for g in v.groups] for v in o.data.vertices]) for o in meshes}
for o in meshes:
 bpy.context.view_layer.objects.active=o
 for modifier in list(o.modifiers):
  if modifier.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=modifier.name)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:
 modifier=o.modifiers.new('Palmar_calibrated_skin','ARMATURE');modifier.object=rig
 assert weights[o.name]==str([[(g.group,g.weight) for g in v.groups] for v in o.data.vertices])
out=r/'assets/models/task009/v009_grip';out.mkdir(parents=True,exist_ok=True);source=r/'assets/source/task009/v009_grip';source.mkdir(parents=True,exist_ok=True);(source/'.gdignore').touch()
bpy.ops.object.select_all(action='DESELECT')
for o in [rig]+meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'arms_palmar_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'Arms_Palmar_Candidate.blend'))
report['model']='res://assets/models/task009/v009_grip/arms_palmar_candidate.glb';report['source_blend']='res://assets/source/task009/v009_grip/Arms_Palmar_Candidate.blend'
g=report['hands']['R']['target_bone_godot'];q=matrix(g).to_quaternion();report['right_grip_socket']={'position':g['origin'],'rotation':[q.x,q.y,q.z,q.w]}
(r/'logs/TASK-009-v009-grip-build.json').write_text(json.dumps(report,indent=2));print('PALMAR_CANDIDATE_EXPORTED edge_increase_m=',excess,flush=True)
