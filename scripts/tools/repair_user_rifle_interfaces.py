"""Repair derived boolean interface slots, preserving the v001 checkpoint and source files."""
import bpy
import json
from pathlib import Path

root=Path(__file__).resolve().parents[2]
assert bpy.data.filepath==''
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/source/task009/user_rifle/AR15_Prepared_v001.blend'))
dark=bpy.data.materials['Dark_component_interfaces']
fixed={}
for name in ('Rifle_Body','Magazine'):
    obj=bpy.data.objects[name]
    index=next(i for i,m in enumerate(obj.data.materials) if m==dark)
    count=0
    for face in obj.data.polygons:
        if obj.data.materials[face.material_index] is None or abs(face.center.z+.07)<.0003:
            face.material_index=index
            count+=1
    fixed[name]=count
    assert all(obj.data.materials[p.material_index] is not None for p in obj.data.polygons)
bpy.ops.object.select_all(action='DESELECT')
for name in ('Rifle_Body','Magazine','Optic_Glass'):
    bpy.data.objects[name].select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['Rifle_Body']
output=root/'assets/models/task009/user_ar15_v002.glb'
bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',use_selection=True,export_apply=True,
                          export_yup=True,export_cameras=False,export_lights=False)
source=root/'assets/source/task009/user_rifle/AR15_Prepared_v002.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
path=root/'logs/TASK-009-user-ar15-bake-audit.json'
report=json.loads(path.read_text())
report.update({'runtime_glb':output.relative_to(root).as_posix(),'source_blend':source.relative_to(root).as_posix(),
               'explicit_interface_faces':fixed})
path.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('REPAIRED INTERFACES',fixed)
