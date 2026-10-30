import bpy
from pathlib import Path
from mathutils import Vector
r=Path(r'C:/Users/AYOU/Desktop/CS');bpy.ops.wm.open_mainfile(filepath=str(r/'assets/source/task009/v004/Gloves_Derived.blend'));a=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE');bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
def g(v):return (round(v.x,4),round(v.z,4),round(-v.y,4))
for s,suffix in [('R','.R_'),('L','.L_')]:
 h=a.pose.bones[s+'_Hand'];print(s,'WRIST',g(h.matrix.translation),'INDEX',g(next(b for b in a.pose.bones if b.name.startswith('index_L'+suffix)).matrix.translation),'THUMB',g(next(b for b in a.pose.bones if b.name.startswith('thumb_L'+suffix)).matrix.translation))
 for prefix in ['middle_L','ring_L','pink_L']:
  bone=next(b for b in a.pose.bones if b.name.startswith(prefix+suffix));print(prefix,g(bone.matrix.translation),'tip',g((a.pose.bones[next(x.name for x in a.data.bones if x.name.startswith(prefix+'.001'+suffix))].matrix.translation)))
