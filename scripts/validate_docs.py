#!/usr/bin/env python3
"""轻量文档/数据检查，不涉及启动 Godot。"""
from pathlib import Path
import json
import sys

root = Path(__file__).resolve().parents[1]
required = [root / 'AGENTS.md',root / 'README.md',root / 'PROMPT_FIRST_RUN.md']
required += list((root/'docs').glob('*.md'))
required += list((root/'tasks').glob('TASK-*.md'))
assert len(list((root/'docs').glob('*.md'))) >= 10, '缺少设计文档'
assert len(list((root/'tasks').glob('TASK-*.md'))) >= 7, '缺少任务卡'
errors=[]
for p in required:
    if not p.exists() or p.stat().st_size < 60:
        errors.append(f'missing/empty {p.relative_to(root)}')
try:
    level=json.loads((root/'data/vertical_slice.json').read_text(encoding='utf-8'))
    assert level['bounds']['z_start']>level['bounds']['z_end']
    assert len(level['encounters'])==3
    assert len({e['enemy_id'] for e in level['encounters']})==3
    assert all(level['bounds']['z_end']<=e['activate_at_z']<=level['bounds']['z_start'] for e in level['encounters'])
    registry=json.loads((root/'data/asset_registry.json').read_text(encoding='utf-8'))
    assert all(e['status'] in ('missing','placeholder','ready') for e in registry['entries'])
    campaign=json.loads((root/'data/campaign.json').read_text(encoding='utf-8'))
    assert campaign['schema_version']=='1.0' and campaign['start_id'] in {e['id'] for e in campaign['levels']}
    sample_physics=json.loads((root/'data/art_sample_physics.json').read_text(encoding='utf-8'))
    assert sample_physics['schema_version']=='1.0'
    assert all(len(e['position'])==3 and len(e['size'])==3 and all(v>0 for v in e['size']) for e in sample_physics['debris_boxes'])
except Exception as ex:
    errors.append(f'JSON: {ex}')
if errors:
    print('文档验证失败:')
    for e in errors: print('-',e)
    sys.exit(1)
print(f'文档检查通过：{len(required)} 个主文档/任务文件 + 4 个 JSON 数据合同。')
print('注意：这不代表 Godot 游戏已构建或实机运行。')
