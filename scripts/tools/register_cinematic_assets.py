"""Register actual TASK-009 exports; keep external user models and existing entries."""
from pathlib import Path
import json

root = Path(__file__).resolve().parents[2]
audit = json.loads((root/'logs/TASK-009-asset-audit.json').read_text(encoding='utf-8'))
path = root/'data/asset_registry.json'
registry = json.loads(path.read_text(encoding='utf-8'))
by_id = {e['id']:e for e in registry['entries']}
for asset,asset_id,category in zip(audit['assets'],('fps_rifle_m4_sample','cinematic_skyline'),('weapon','environment')):
    if category=='weapon' and by_id.get(asset_id,{}).get('user_delivery'):
        asset_id='fps_rifle_m4_fallback'
    file = root/'assets/models/task009'/(asset['id']+'.glb')
    assert file.exists()
    by_id[asset_id] = {'id':asset_id,'category':category,'status':'ready',
        'proposed_path':'res://'+file.relative_to(root).as_posix(),'required_for_mvp':False,
        'source':audit['source'],'license':audit['license'],'triangles':asset['triangles'],
        'source_blend':'res://'+audit['source_blend'],
        'texture_resolutions':audit['texture_resolutions'] if category=='weapon' else {},
        'units':'meters','forward_axis':'-Z','collision':'none; presentation only',
        'review_status':'sample_pending_user_visual_acceptance',
        'usage_restrictions':'TASK-009 sample, not final photographic quality or official manufacturer asset'}
registry['entries'] = list(by_id.values())
path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered actual M4-style rifle sample and skyline; other asset entries preserved.')
