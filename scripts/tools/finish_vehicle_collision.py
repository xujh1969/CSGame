"""Derive two small convex support hulls from the prepared LP; no rebake required."""
import bpy
import json
import math
import numpy as np
from pathlib import Path
from mathutils import Matrix

root = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root/'assets/source/task008/vehicle/VehicleBake_v001.blend'))
low = bpy.data.objects['Vehicle_Low_Runtime']
path = root/'logs/TASK-008-vehicle-bake-audit.json'
report = json.loads(path.read_text(encoding='utf-8'))
if not report.get('front_axis_corrected'):
    for name in ('Vehicle_Low_Runtime', 'Vehicle_High_Source'):
        obj = bpy.data.objects[name]
        obj.data.transform(Matrix.Rotation(math.pi, 4, 'Z'))
        obj.data.update()
    bpy.ops.object.select_all(action='DESELECT')
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.export_scene.gltf(filepath=str(root/report['runtime_glb']),export_format='GLB',use_selection=True,
                              export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    report['front_axis_corrected'] = True
    report['front_axis_godot'] = '-Z'
    report['runtime_bytes'] = (root/report['runtime_glb']).stat().st_size
points = np.array([tuple(v.co) for v in low.data.vertices])

def hull(points):
    indices = set()
    for index in range(96):
        z = 1-2*(index+.5)/96
        radius = math.sqrt(1-z*z)
        angle = index*math.pi*(3-math.sqrt(5))
        direction = np.array([radius*math.cos(angle),radius*math.sin(angle),z])
        indices.add(int(np.argmax(points@direction)))
    return [[float(p[0]),float(p[2]),float(-p[1])] for p in points[sorted(indices)]]

report['collision_hulls'] = [hull(points[points[:,2] <= .86]),hull(points[points[:,2] >= .72])]
path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Actual LP collision hull point counts:',[len(h) for h in report['collision_hulls']])
