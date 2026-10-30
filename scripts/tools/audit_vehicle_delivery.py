"""Read-only delivery audit in an isolated Blender process; never saves over user files."""
import bpy
import json
import time
import struct
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
paths = [root/'assets/models/废弃汽车-低模.glb', root/'assets/models/废弃汽车.fbx']
report = {'blender':bpy.app.version_string,'files':[]}
for path in paths:
    started = time.perf_counter()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if path.suffix.lower() == '.glb':
        raw = path.read_bytes()
        length = struct.unpack_from('<I',raw,12)[0]
        document = json.loads(raw[20:20+length])
        bpy.ops.import_scene.gltf(filepath=str(path))
    else:
        document = None
        bpy.ops.import_scene.fbx(filepath=str(path), use_image_search=True)
    bpy.context.view_layer.update()
    meshes = [obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    corners = [obj.matrix_world @ Vector(c) for obj in meshes for c in obj.bound_box]
    low = [min(c[i] for c in corners) for i in range(3)]
    high = [max(c[i] for c in corners) for i in range(3)]
    materials = []
    for material in bpy.data.materials:
        textures = []
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image:
                    textures.append({'image':node.image.name,'size':list(node.image.size),
                                     'packed':bool(node.image.packed_file),'path':node.image.filepath,
                                     'has_data':node.image.has_data})
        materials.append({'name':material.name,'textures':textures,'diffuse':list(material.diffuse_color)})
    item = {'path':str(path),'bytes':path.stat().st_size,'import_seconds':time.perf_counter()-started,
            'objects':[{'name':o.name,'vertices':len(o.data.vertices),
                        'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
                        'uv_layers':list(o.data.uv_layers.keys()),'color_attributes':list(o.data.color_attributes.keys())} for o in meshes],
            'bounds_blender':[low,high],'dimensions_blender':[high[i]-low[i] for i in range(3)],
            'materials':materials,'images':[{'name':i.name,'size':list(i.size),'packed':bool(i.packed_file),'has_data':i.has_data} for i in bpy.data.images]}
    if document:
        item['gltf_images'] = document.get('images',[])
        item['gltf_extensions'] = document.get('extensionsUsed',[])
    report['files'].append(item)
    (root/'logs/TASK-008-vehicle-delivery-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print('DELIVERY',path.name,'triangles',sum(o['triangles'] for o in item['objects']),
          'dimensions',item['dimensions_blender'],'images',len(item['images']),flush=True)
print('VEHICLE AUDIT COMPLETE',flush=True)
