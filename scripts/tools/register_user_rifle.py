"""Activate the user's prepared AR, retaining the project rifle as fallback."""
from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
audit=json.loads((root/'logs/TASK-009-user-ar15-bake-audit.json').read_text(encoding='utf-8'))
assert audit['raw_files_unchanged']
assert (root/audit['runtime_glb']).exists()
path=root/'data/asset_registry.json'
registry=json.loads(path.read_text(encoding='utf-8'))
entries={e['id']:e for e in registry['entries']}
existing=entries['fps_rifle_m4_sample']
if not existing.get('user_delivery'):
    fallback=dict(existing)
    fallback['id']='fps_rifle_m4_fallback'
    entries[fallback['id']]=fallback
entries['fps_rifle_m4_sample']={'id':'fps_rifle_m4_sample','category':'weapon','status':'ready',
    'proposed_path':'res://'+audit['runtime_glb'],'required_for_mvp':False,
    'source':audit['source_tool']+'; user LP + HP PBR bake; magazine split and optic bore repaired',
    'source_blend':'res://'+audit['source_blend'],'license':audit['license'],
    'triangles':sum(audit['components'].values()),'components':audit['components'],
    'raw_sha256':audit['raw_sha256'],'texture_resolution':audit['texture_size'],
    'mounts':{'muzzle':audit['muzzle_godot'],'sight':audit['sight_center_godot']},
    'user_delivery':True,'fallback_asset':'fps_rifle_m4_fallback','units':'meters','forward_axis':'-Z',
    'collision':'visual only; existing weapon collision queries authoritative',
    'review_status':'user_ar15_pending_visual_acceptance'}
registry['entries']=list(entries.values())
path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Activated actual user AR-15:',sum(audit['components'].values()),'triangles; procedural fallback preserved')
