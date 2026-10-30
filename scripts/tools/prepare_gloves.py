"""Retarget the delivered CC-BY glove rig, retaining its original weights and PBR."""
import bpy,math,json,hashlib
from pathlib import Path
from mathutils import Vector,Matrix,Quaternion
r=Path(__file__).resolve().parents[2];src=r/'assets/models/hand_with_gloves.glb';out=r/'assets/source/task009/v005';out.mkdir(parents=True,exist_ok=True);(out/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(src))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');meshes=[bpy.data.objects[n] for n in ('Object_7','Object_9')]
def weight_signature(mesh):
 return hashlib.sha256(json.dumps([[(g.group,g.weight) for g in v.groups] for v in mesh.data.vertices]).encode()).hexdigest()
original_weights={o.name:weight_signature(o) for o in meshes}
# Source bind geometry and inverse-bind rest are far from the posed display origin.
# Transform both by the same matrix, never bake a posed mesh against an unposed rig.
world=rig.matrix_world.copy();origin=(world@rig.data.bones['upperarm_L.L_30'].head_local+world@rig.data.bones['upperarm_L.R_56'].head_local)/2
scale=.34/(world.to_3x3()@(rig.data.bones['lowerarm_L.L_29'].head_local-rig.data.bones['upperarm_L.L_30'].head_local)).length
N=Matrix.Diagonal((scale,scale,scale,1))@Matrix.Translation(-origin)
for o in meshes:
 transform=N@o.matrix_world;o.parent=None;o.matrix_world=Matrix.Identity(4);o.data.transform(transform)
rig.parent=None;rig.data.transform(N@world);rig.matrix_world=Matrix.Identity(4)
for b in rig.pose.bones:b.matrix_basis=Matrix.Identity(4)
for o in list(bpy.context.scene.objects):
 if o!=rig and o not in meshes:bpy.data.objects.remove(o,do_unlink=True)
# Match the existing runtime's six semantic joints; keep all native finger/twist weights.
# Native author suffixes describe the opposite visible hand in the delivered reference.
map_names={'R':('upperarm_L.L_30','lowerarm_L.L_29','hand_L.L_25'),'L':('upperarm_L.R_56','lowerarm_L.R_55','hand_L.R_51')}
original={k:v for k,v in map_names.items()}
for side,names in map_names.items():
 for old,new in zip(names,('Upper','Forearm','Hand')):
  name=side+'_'+new;rig.data.bones[old].name=name
  for mesh in meshes:
   if old in mesh.vertex_groups:mesh.vertex_groups[old].name=name
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for side in ('L','R'):rig.data.edit_bones[side+'_Upper'].parent=None
bpy.ops.object.mode_set(mode='OBJECT')
for o in meshes:o.parent=rig;o.matrix_parent_inverse=Matrix.Identity(4)
conv=Matrix(((1,0,0),(0,0,-1),(0,1,0)))
def g(v):return conv.inverted()@v
def b(v):return conv@v
rests={s:[g(rig.data.bones[s+'_'+n].head_local) for n in ('Upper','Forearm','Hand')] for s in ('L','R')}
frames={}
for side,suffix in (('L','.R_'),('R','.L_')):
 hand=rig.data.bones[side+'_Hand'];finger=lambda prefix:next(x for x in rig.data.bones if x.name.startswith(prefix+suffix))
 index=finger('index_L');pink=finger('pink_L');middle=finger('middle_L')
 y=(g(hand.head_local)-g(middle.head_local)).normalized()
 x=(g(index.head_local)-g(pink.head_local)).normalized()*(1 if side=='L' else -1)
 x=(x-y*x.dot(y)).normalized();z=x.cross(y).normalized();frames[side]=Matrix((x,y,z)).transposed()
rig.animation_data_create()
for bone in rig.pose.bones:bone.rotation_mode='QUATERNION'
def smooth(a,b,x):t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def pose(side,wrist,canonical):
 joints=rests[side];rotation=canonical@frames[side].inverted();shoulder=Vector((.27,-.28,.35)) if side=='R' else Vector((-.32,-.26,.20))
 l1=(joints[1]-joints[0]).length;l2=(joints[2]-joints[1]).length;direction=wrist-shoulder;d=min(direction.length,l1+l2-.001);direction.normalize();wrist=shoulder+direction*d
 p=(l1*l1-l2*l2+d*d)/(2*d);pole=Vector((1 if side=='R' else -1,-1,.1));bend=(pole-direction*pole.dot(direction)).normalized();elbow=shoulder+direction*p+bend*math.sqrt(max(0,l1*l1-p*p))
 fore=(rotation@(joints[2]-joints[1])).rotation_difference(wrist-elbow).to_matrix()@rotation
 upper=(fore@(joints[1]-joints[0])).rotation_difference(elbow-shoulder).to_matrix()@fore
 for name,origin,rest,rot in [('Upper',shoulder,joints[0],upper),('Forearm',elbow,joints[1],fore),('Hand',wrist,joints[2],rotation)]:
  bone=rig.pose.bones[side+'_'+name];bone.matrix=Matrix.Translation(b(origin))@(conv@rot@conv.inverted()).to_4x4()@Matrix.Translation(-b(rest))@bone.bone.matrix_local;bpy.context.view_layer.update()
def fingers(side,amount,trigger=0):
 suffix='.R_' if side=='L' else '.L_';axis=b(frames[side].col[0])
 for family in ('index_L','middle_L','ring_L','pink_L','thumb_L'):
  bone=next(x for x in rig.pose.bones if x.name.startswith(family+suffix))
  chain=[]
  while bone:
   chain.append(bone);bone=next((x for x in bone.children if x.name.startswith(family)),None)
  angles=(.10,.20,.10) if family=='thumb_L' else ((.85,1.10,.60,0) if side=='R' else (.70,1.0,.55,0))
  if side=='R' and family=='index_L':angles=(.22+trigger,.35,.18,0)
  for joint,angle in zip(chain,angles):
   local=joint.bone.matrix_local.to_3x3().inverted()@axis
   joint.rotation_quaternion=Quaternion(local.normalized(),-angle*amount)
# Native canonical +Z points into the palm, opposite the prior generated arm mesh.
flip=Matrix.Rotation(math.pi,3,'Y')
right=Matrix(((0,0,-1),(-1,0,0),(0,1,0)))
left=Matrix(((0,-1,0),(0,0,-1),(1,0,0)))@flip
reload=Matrix(((0,0,1),(1,0,0),(0,1,0)))
for animation in ('Hold','Fire','Reload'):
 action=bpy.data.actions.new(animation);rig.animation_data.action=action
 for frame in (range(1,134,3) if animation=='Reload' else ((1,4,8) if animation=='Fire' else (1,4))):
  bpy.context.scene.frame_set(frame);t=(frame-1)/132 if animation=='Reload' else 0;mix=smooth(.02,.17,t)*(1-smooth(.84,.98,t));extract=smooth(.18,.38,t)*(1-smooth(.62,.82,t))
  for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
  wrist=Vector((-.075,-.037,-.09)).lerp(Vector((-.045,-.20,.06)),mix)+Vector((0,-.14,.025))*extract
  pose('R',Vector((.045,-.11,.205)),right);pose('L',wrist,left.to_quaternion().slerp(reload.to_quaternion(),mix).to_matrix());fingers('R',1,.12*math.sin(math.pi*(frame-1)/7) if animation=='Fire' else 0)
  grasp=1-smooth(.02,.08,t)*(1-smooth(.13,.18,t))-smooth(.82,.88,t)*(1-smooth(.94,.99,t))
  fingers('L',(.8+.2*mix)*grasp)
  for bone in rig.pose.bones:
   bone.keyframe_insert(data_path='location',frame=frame);bone.keyframe_insert(data_path='rotation_quaternion',frame=frame)
 track=rig.animation_data.nla_tracks.new();track.name=animation;track.strips.new(animation,1,action)
rig.animation_data.action=None;bpy.context.scene.render.fps=60;bpy.context.scene.frame_set(1)
for o in meshes:
 for mat in o.data.materials:
  if mat:mat.use_backface_culling=True
bpy.ops.object.select_all(action='DESELECT')
for o in [rig]+meshes:o.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=r/'assets/models/task009/v005';runtime.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(runtime/'gloves_rigged.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_cameras=False,export_lights=False)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Gloves_Derived.blend'))
assert all(weight_signature(o)==original_weights[o.name] for o in meshes), 'Native weights changed'
right_bone=rig.pose.bones['R_Hand'].matrix.copy()
right_q=(conv.inverted()@right_bone.to_3x3()@conv).to_quaternion()
right_socket={'position':list(g(right_bone.translation)),'rotation':[right_q.x,right_q.y,right_q.z,right_q.w]}
report={'right_grip_socket':right_socket,'source_hand_mapping':{'R':'native .L','L':'native .R'},'weight_audit':original_weights,'raw_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'triangles':sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'bones':list(rig.data.bones.keys()),'animations':['Hold','Fire','Reload'],'source':'https://sketchfab.com/3d-models/hand-with-gloves-5a6a434b8ec943ffacc581358781eecb','author':'JUST (https://sketchfab.com/teenjust500)','license':'CC-BY-4.0; embedded metadata, download page fetch 403','retained_original_weights':True,'scale':scale,'palm_axes':{side:list(rig.data.bones[side+'_Hand'].matrix_local.to_3x3().inverted()@b(frames[side].col[2])) for side in ('R','L')}}
(r/'logs/TASK-009-gloves-build.json').write_text(json.dumps(report,indent=2));print('GLOVES_EXPORTED',report['triangles'],len(report['bones']),flush=True)
