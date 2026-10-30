"""Generate an actual glTF 2 binary mesh, only for resource-interface tests.
Original project-generated geometry; no third-party assets or dependencies.
This small orange box is not production art.
"""
import json
import struct
from pathlib import Path

vertices = [(-.45, -.275, -.175), (.45, -.275, -.175), (.45, .275, -.175),
            (-.45, .275, -.175), (-.45, -.275, .175), (.45, -.275, .175),
            (.45, .275, .175), (-.45, .275, .175)]
indices = [0, 2, 1, 0, 3, 2, 4, 5, 6, 4, 6, 7, 0, 1, 5, 0, 5, 4,
           3, 7, 6, 3, 6, 2, 1, 2, 6, 1, 6, 5, 0, 4, 7, 0, 7, 3]
positions = struct.pack('<24f', *(n for point in vertices for n in point))
triangles = struct.pack('<36H', *indices)
binary = positions + triangles
gltf = {
    'asset': {'version': '2.0', 'generator': 'CS test fixture; original geometry'},
    'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'mesh': 0, 'name': 'TestVisualOnly'}],
    'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1, 'material': 0}]}],
    'materials': [{'doubleSided': True, 'pbrMetallicRoughness': {
        'baseColorFactor': [1, .35, .05, 1], 'metallicFactor': 0, 'roughnessFactor': .9}}],
    'buffers': [{'byteLength': len(binary)}],
    'bufferViews': [{'buffer': 0, 'byteOffset': 0, 'byteLength': len(positions), 'target': 34962},
                    {'buffer': 0, 'byteOffset': len(positions), 'byteLength': len(triangles), 'target': 34963}],
    'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': 8, 'type': 'VEC3',
                   'min': [-.45, -.275, -.175], 'max': [.45, .275, .175]},
                  {'bufferView': 1, 'componentType': 5123, 'count': 36, 'type': 'SCALAR'}],
}
header = json.dumps(gltf, separators=(',', ':')).encode()
header += b' ' * (-len(header) % 4)
binary += b'\0' * (-len(binary) % 4)
content = (struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(header) + 8 + len(binary))
           + struct.pack('<II', len(header), 0x4E4F534A) + header
           + struct.pack('<II', len(binary), 0x004E4942) + binary)
Path(__file__).with_name('visual_only.glb').write_bytes(content)
print(f'Wrote real test-only GLB: {len(content)} bytes')
