"""Activate only the inspected derived resources for the opt-in TASK-009 sample."""
from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
path=root/'data/asset_registry.json'
registry=json.loads(path.read_text(encoding='utf-8'))
entries={e['id']:e for e in registry['entries']}
old=entries['fps_rifle_m4_sample']
if '/v003/' not in old['proposed_path']:
    entries['fps_rifle_ar15_v002']={**old,'id':'fps_rifle_ar15_v002'}
for asset,key,category in [('new_ar','fps_rifle_m4_sample','weapon'),('arms','player_fp_arms','character'),
                           ('clutter1','street_clutter1','prop'),('clutter2','street_clutter2','prop'),('clutter3','street_clutter3','prop')]:
    if asset=='arms' and entries.get(key,{}).get('proposed_path','').endswith('gloves_rigged.glb'):
        continue
    baked=json.loads((root/'logs'/('TASK-009-v003-bake-'+asset+'.json')).read_text())
    parts=json.loads((root/'logs'/('TASK-009-v003-parts-'+asset+'.json')).read_text())
    assert baked['raw_files_unchanged'] and (root/parts['runtime_glb']).exists()
    raw_hashes={'assets/models/'+p:h for p,h in baked['raw_sha256'].items()}
    entry={'id':key,'category':category,'status':'ready','proposed_path':'res://'+parts['runtime_glb'],
           'source':'User delivery; new batch tool not reconfirmed; derived LP + HP bake',
           'license':'User supplied; terms not supplied; local evaluation', 'source_blend':'res://'+parts['source_blend'],
           'raw_sha256':raw_hashes,'texture_resolution':[2048,2048],'units':'meters',
           'review_status':'v003_pending_user_acceptance','user_delivery':True,'required_for_mvp':False}
    if asset=='new_ar':
        entry.update({'triangles':sum(parts['components'].values()),'components':parts['components'],
                      'mounts':{'muzzle':parts['muzzle_godot'],'sight':parts['sight_center_godot']},
                      'fallback_asset':'fps_rifle_ar15_v002'})
    elif asset=='arms':
        entry.update({'triangles':parts['triangles'],'bones':parts['bones'],'animations':parts['animations'],
                      'limitation':parts['limitation']})
    else:
        entry['variants']=parts['variants']
    entries[key]=entry
registry['entries']=list(entries.values())
path.write_text(json.dumps(registry,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Registered new AR, basic skinned arms and three clutter libraries; prior resources retained')
