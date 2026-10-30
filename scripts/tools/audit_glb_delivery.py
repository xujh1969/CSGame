"""Read-only audit of this user delivery; an existing recorded hash must match."""
from pathlib import Path
import struct
import json
import hashlib

root=Path(__file__).resolve().parents[2]
path=root/'logs/TASK-009-user-delivery-audit.json'
previous={Path(r['file']).name:r['sha256'] for r in json.loads(path.read_text(encoding='utf-8'))} if path.exists() else {}
rows=[]
for name in ('AR-15低模.glb','AR-15.glb','AK-47低模.glb','AK-47.glb','杂物1-低模.glb','杂物1.glb'):
    file=root/'assets/models'/name
    binary=file.read_bytes()
    digest=hashlib.sha256(binary).hexdigest()
    assert not previous or previous[name]==digest,'Source changed: '+name
    size,kind=struct.unpack_from('<II',binary,12)
    document=json.loads(binary[20:20+size])
    triangles=0
    for mesh in document.get('meshes',[]):
        for primitive in mesh['primitives']:
            if primitive.get('mode',4)==4:
                index=primitive.get('indices',primitive['attributes']['POSITION'])
                triangles+=document['accessors'][index]['count']//3
    rows.append({'file':file.relative_to(root).as_posix(),'bytes':len(binary),'sha256':digest,
                 'triangles':triangles,'meshes':len(document.get('meshes',[])),
                 'materials':len(document.get('materials',[])),'images':len(document.get('images',[])),
                 'source_tool':'Hunyuan3D, confirmed by user'})
path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS: six raw user GLBs unchanged; sources audited without import or mutation')
