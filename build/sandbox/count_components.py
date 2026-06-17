import sys, re
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

def count_components(path, tol=1e-3):
    tris = load_ascii_stl(path)
    n = len(tris)
    verts = tris.reshape(-1, 3)
    rounded = np.round(verts / tol).astype(np.int64)
    keys = [tuple(r) for r in rounded]
    key_to_id = {}
    vert_ids = []
    for k in keys:
        if k not in key_to_id:
            key_to_id[k] = len(key_to_id)
        vert_ids.append(key_to_id[k])
    vert_ids = np.array(vert_ids).reshape(n, 3)

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

    roots = {}
    for i in range(len(key_to_id)):
        r = find(i)
        roots.setdefault(r, 0)
        roots[r] += 1

    print(f"{path}: {n} triangles, {len(key_to_id)} unique verts, {len(roots)} connected components")
    sizes = sorted(roots.values(), reverse=True)
    print(f"  component vert-counts (top 10): {sizes[:10]}")

for p in sys.argv[1:]:
    count_components(p)
