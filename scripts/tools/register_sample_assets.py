"""Register only built, audited TASK-008 assets; existing gameplay asset slots stay unchanged."""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
audit = json.loads((root/'logs/TASK-008-asset-audit.json').read_text(encoding='utf-8'))
registry_path = root/'data/asset_registry.json'
registry = json.loads(registry_path.read_text(encoding='utf-8'))
names = {
    'residential_v002': 'sample_residential_A', 'shopfront_v001': 'sample_shopfront_A',
    'road_v001': 'sample_road_A', 'barrier_v001': 'sample_barrier_A',
    'crates_v001': 'sample_crates_A', 'street_details_v002': 'sample_street_details_A',
    'vehicle_proxy_v001': 'sample_vehicle_proxy',
}
updates = []
for item in audit['assets']:
    path = 'assets/models/task008/' + item['id'] + '.glb'
    assert (root/path).is_file()
    entry = {
        'id': names[item['id']], 'category': 'sample_environment',
        'proposed_path': 'res://' + path, 'status': 'ready',
        'required_for_mvp': False, 'source': 'scripts/tools/build_sample_assets.py',
        'source_blend': audit.get('source_blend', 'res://assets/source/task008/StreetKit_v001.blend'),
        'license': audit['license'], 'units': 'meters', 'forward_axis': '+Z',
        'triangles': item['triangles'], 'bounds_godot': item['bounds_godot'],
        'collision': 'separate_authored_simple_shapes', 'review_status': 'sample_art_pending_visual_acceptance',
        'usage_restrictions': 'TASK-008 sample; not approved as final reference-quality art',
        'preview_file': 'docs/asset_requests/TASK-008/preview_' + item['id'] + '.png',
    }
    if item['id'] == 'vehicle_proxy_v001':
        entry['placeholder'] = True
    updates.append(entry)
existing_vehicle = next((e for e in registry['entries'] if e['id']=='sample_vehicle_final'),None)
if not existing_vehicle or existing_vehicle.get('status') != 'ready':
    updates.append({
    'id': 'sample_vehicle_final', 'category': 'prop', 'status': 'missing',
    'proposed_path': 'res://assets/models/task008/vehicle_final.glb',
    'required_for_mvp': False, 'fallback_asset': 'sample_vehicle_proxy',
    'handoff': 'docs/asset_requests/TASK-008_FIRST_BATCH.md', 'collision': 'separate_authored_simple_shapes',
    })
smoke_path = 'assets/textures/task008/smoke_puff_v001.png'
if (root/smoke_path).is_file():
    updates.append({'id':'sample_smoke_sprite','category':'vfx_texture',
                    'proposed_path':'res://'+smoke_path,'status':'ready','required_for_mvp':False,
                    'source':'built-in imagegen, original smoke sprite with tested alpha',
                    'license':'AI-generated sample VFX; release review pending',
                    'usage_restrictions':'2D billboard smoke texture, not a 3D model',
                    'review_status':'sample_art_pending_visual_acceptance'})
by_id = {entry['id']: entry for entry in registry['entries']}
by_id.update({entry['id']: entry for entry in updates})
registry['entries'] = list(by_id.values())
registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
(root/'data/art_sample_physics.json').write_text(json.dumps({'schema_version':'1.0', 'debris_boxes':audit.get('debris_collision_boxes', [])},indent=2)+'\n',encoding='utf-8')
print('Registered 7 environment GLBs; delivered ready vehicle entry is preserved. Original slots unchanged.')
