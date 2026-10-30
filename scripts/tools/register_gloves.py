"""Register the inspected glove derivative without replacing the source or v003 fallback."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
path = root / 'data/asset_registry.json'
registry = json.loads(path.read_text(encoding='utf-8'))
report = json.loads((root / 'logs/TASK-009-gloves-build.json').read_text(encoding='utf-8'))
raw = root / 'assets/models/hand_with_gloves.glb'
assert hashlib.sha256(raw.read_bytes()).hexdigest() == report['raw_sha256']
entry = next(e for e in registry['entries'] if e['id'] == 'player_fp_arms')
if not any(e['id'] == 'player_fp_arms_v003' for e in registry['entries']):
    registry['entries'].append({**entry, 'id': 'player_fp_arms_v003'})
entry.update({
    'proposed_path': 'res://assets/models/task009/v005/gloves_rigged.glb',
    'source_blend': 'res://assets/source/task009/v005/Gloves_Derived.blend',
    'source': report['source'], 'author': report['author'], 'license': report['license'],
    'raw_sha256': {'assets/models/hand_with_gloves.glb': report['raw_sha256']},
    'triangles': report['triangles'], 'bones': report['bones'],
    'animations': report['animations'], 'palm_axes': report['palm_axes'],
    'source_hand_mapping': report['source_hand_mapping'],
    'right_grip_socket': report['right_grip_socket'],
    'review_status': 'v005_pending_user_acceptance',
    'limitation': 'Retargeted native glove skin; visual grip and reload acceptance pending',
})
entry.pop('texture_resolution', None)
path.write_text(json.dumps(registry, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Registered native glove rig; source SHA256 unchanged')
