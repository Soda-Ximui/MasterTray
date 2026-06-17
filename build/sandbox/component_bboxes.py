import sys
import numpy as np

def load_ascii_stl(path):
    verts = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("vertex"):
                parts = line.split()
                verts.append([float(parts[1]), float(parts[2]), float(parts[3])])
    verts = np.array(verts, dtype=np.float64).reshape(-1, 3, 3)
    return verts

def component_bboxes(path, tol=1e-3, top_n=20):
    tris = load_ascii_stl(path)
    n = len(tris)
    verts = tris.reshape(-1, 3)
    rounded = np.round(verts / tol).astype(np.int64)
    keys = [tuple(r) for r in rounded]
    key_to_id = {}
    coords = []
    vert_ids = []
    for k, v in zip(keys, verts):
        if k not in key_to_id:
            key_to_id[k] = len(key_to_id)
            coords.append(v)
        vert_ids.append(key_to_id[k])
    vert_ids = np.array(vert_ids).reshape(n, 3)
    coords = np.array(coords)

    parent = list(range(len(key_to_id)))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for tri in vert_ids:
        union(tri[0], tri[1])
        union(tri[1], tri[2])

    groups = {}
    for i in range(len(key_to_id)):
        r = find(i)
        groups.setdefault(r, []).append(i)

    print(f"{path}: {len(groups)} connected components")
    items = sorted(groups.items(), key=lambda kv: -len(kv[1]))
    for r, idxs in items[:top_n]:
        pts = coords[idxs]
        bmin = pts.min(axis=0)
        bmax = pts.max(axis=0)
        print(f"  verts={len(idxs):5d}  bbox X[{bmin[0]:.2f},{bmax[0]:.2f}] "
              f"Y[{bmin[1]:.2f},{bmax[1]:.2f}] Z[{bmin[2]:.2f},{bmax[2]:.2f}]")

for p in sys.argv[1:]:
    component_bboxes(p)
