"""Read original neutral finger chains; do not alter the rig."""
import bpy,json
from pathlib import Path
from mathutils import Matrix
r=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v005/Gloves_Derived.blend'))
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
rows=[]
for side,suffix,old in [('R','.R_','L'),('L','.L_','R')]:
 hand=rig.data.bones[old+'_Hand']
 for family in ('index_L','middle_L','ring_L','pink_L','thumb_L'):
  bone=next(b for b in rig.data.bones if b.name.startswith(family+suffix));chain=[]
  while bone:
   chain.append({'name':bone.name,'head_m':list(C@bone.head_local),'tail_m':list(C@bone.tail_local),'distance_from_wrist_m':(bone.head_local-hand.head_local).length,'length_m':bone.length})
   bone=next((b for b in bone.children if b.name.startswith(family)),None)
  rows.append({'side':side,'family':family,'chain':chain})
(r/'logs/TASK-009-finger-chain-audit.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
print('FINGER_CHAINS',json.dumps(rows))
