"""Solve a new diagnostic-only rig from measured palmar markers, not wrist guesses."""
import bpy,json,hashlib,math
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
r=Path(__file__).resolve().parents[2];cal=json.loads((r/'logs/TASK-009-palmar-calibration-native.json').read_text())
assert cal['source_glb_sha256']==hashlib.sha256((r/'assets/models/task009/v005/gloves_rigged.glb').read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];rig.animation_data_clear()
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4);bone.rotation_mode='QUATERNION'
C=Matrix(((1,0,0),(0,0,1),(0,-1,0))).to_4x4()
def matrix(data):
 m=Matrix(data['basis']).transposed().to_4x4();m.translation=Vector(data['origin']);return m
def local_marker(data):return matrix({'basis':data['bone_local_basis'],'origin':data['bone_local_position']})
def blender(v):return C.inverted()@Vector(v)
report={'method':'Hand_target = desired_palmar_socket * inverse(actual_palmar_marker)','source_glb_sha256':cal['source_glb_sha256'],'hands':{},'animations':[],'source_hand_mapping':{'R':'native .L','L':'native .R'},'original_weights_preserved':True}
for side,key,suffix in [('R','right_grip','.L_'),('L','left_grip','.R_')]:
 data=cal[key];rest_hand=rig.data.bones[side+'_Hand'].matrix_local.copy();g_bind=matrix(data['hand_bind_frame']);correction=(C@rest_hand).inverted()@g_bind
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
 report['hands'][side]={'target_bone_godot':{'origin':list(target_g.translation),'basis':[list(target_g.to_3x3().col[i]) for i in range(3)]},'joint_frame_correction':[list(row) for row in correction],'palmar_calibration':data}
bpy.context.view_layer.update();glove=bpy.data.objects['Object_7'];e=glove.evaluated_get(bpy.context.evaluated_depsgraph_get());m=e.to_mesh();excess=max((m.vertices[x.vertices[0]].co-m.vertices[x.vertices[1]].co).length-(glove.data.vertices[x.vertices[0]].co-glove.data.vertices[x.vertices[1]].co).length for x in glove.data.edges);e.to_mesh_clear();report['prebind_max_edge_length_increase']=excess
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
out=r/'assets/models/task009/v008';out.mkdir(parents=True,exist_ok=True);source=r/'assets/source/task009/v008';source.mkdir(parents=True,exist_ok=True);(source/'.gdignore').touch()
bpy.ops.object.select_all(action='DESELECT')
for o in [rig]+meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'arms_palmar_candidate.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(source/'Arms_Palmar_Candidate.blend'))
report['model']='res://assets/models/task009/v008/arms_palmar_candidate.glb';report['source_blend']='res://assets/source/task009/v008/Arms_Palmar_Candidate.blend'
g=report['hands']['R']['target_bone_godot'];q=matrix(g).to_quaternion();report['right_grip_socket']={'position':g['origin'],'rotation':[q.x,q.y,q.z,q.w]}
(r/'logs/TASK-009-v008-build.json').write_text(json.dumps(report,indent=2));print('PALMAR_CANDIDATE_EXPORTED edge_increase_m=',excess,flush=True)
