"""Register the prepared user vehicle, retaining source hashes and collision support hulls."""
from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
audit=json.loads((root/'logs/TASK-008-vehicle-bake-audit.json').read_text(encoding='utf-8'))
assert audit['raw_files_unchanged']
assert audit['low_triangles'] <= 50000
assert (root/audit['runtime_glb']).is_file()
registry_path=root/'data/asset_registry.json'
registry=json.loads(registry_path.read_text(encoding='utf-8'))
entry=next(e for e in registry['entries'] if e['id']=='sample_vehicle_final')
entry.update({'status':'ready','proposed_path':'res://'+Path(audit['runtime_glb']).as_posix(),
              'source':'User delivery, Hunyuan3D; low geometry + high model material bake',
              'source_blend':'res://'+Path(audit['source_blend']).as_posix(),
              'license':audit['license'],'units':'meters','forward_axis':'-Z',
              'triangles':audit['low_triangles'],'dimensions_m':audit['runtime_dimensions_godot'],
              'texture_resolution':audit['texture_size'],'collision':'two_convex_support_hulls',
              'collision_hulls':audit['collision_hulls'],
              'raw_sha256':audit['raw_sha256'], 'placeholder':False,
              'review_status':'vehicle_integration_pending_visual_acceptance',
              'preview_file':'docs/asset_requests/TASK-008/vehicle_runtime_front.png'})
registry_path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered actual user vehicle:',entry['triangles'],'triangles; original files unchanged.')
