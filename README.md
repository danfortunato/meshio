# meshio for MATLAB

A MATLAB port of [meshio](https://github.com/nschloe/meshio) for reading and writing unstructured mesh files. The API mirrors
the Python package closely: `meshio.read`, `meshio.write`, and a
`meshio.Mesh` container with points, cells, and associated data.

## Requirements

- MATLAB **R2023b or later** (uses `dictionary` / `configureDictionary` and
  `arguments` blocks).

## Installation

```matlab
mip install --channel mip-org/labs meshio
```

The `+meshio` package is then available as the namespace `meshio`.

## Supported formats

| Format | Extensions | Notes |
|--------|------------|-------|
| Gmsh   | `.msh`     | versions 2.2, 4.0, 4.1 (read + write) |
| Netgen | `.vol`, `.vol.gz` | includes periodic meshes |
| OBJ    | `.obj`     | |
| OFF    | `.off`     | |
| PLY    | `.ply`     | ASCII and binary |
| STL    | `.stl`     | ASCII and binary |
| TetGen | `.node`, `.ele` | node/element file pair |

The full Python meshio supports ~31 formats; this port covers the seven above.
Notably **not** yet ported: VTK, VTU, XDMF, Abaqus, Nastran, MED, Medit, and
others.

## Usage

Read a mesh (format is deduced from the extension):

```matlab
mesh = meshio.read('bunny.msh');
disp(mesh)
```

Write a mesh (format deduced from the extension, or given explicitly):

```matlab
meshio.write('out.ply', mesh);                        % format from extension
meshio.write('out.ply', mesh, 'ply', binary=true);    % explicit format + options
```

Build a mesh from scratch:

```matlab
points = [0 0 0; 1 0 0; 1 1 0; 0 1 0];
cells  = {{"triangle", [1 2 3; 1 3 4]}};   % {type, connectivity} pairs
mesh   = meshio.Mesh(points, cells);
```

Convenience writer for the common points+cells case:

```matlab
meshio.write_points_cells('out.off', points, cells);
```

Call a format reader/writer directly when you want format-specific options:

```matlab
m = meshio.ply.read('mesh.ply');
meshio.stl.write('mesh.stl', m, binary=true);
```

## Indexing convention

**Cell connectivity is 1-based** in this port, following MATLAB convention. The
underlying Python meshio uses 0-based indices; readers and writers convert to
and from the on-disk representation automatically, so the indices you see on a
`meshio.Mesh` in MATLAB are always 1-based.

## The `Mesh` object

`meshio.Mesh` is a handle class:

- `points` — `[nPoints x dim]` coordinates
- `cells` — array of `meshio.CellBlock`, each with a `type` and `data`
- `point_data`, `cell_data`, `field_data` — dictionaries of associated data
- `point_sets`, `cell_sets` — named index sets

It also provides `get_cells_type`, `get_cell_data`, `cells_dict`,
`cell_data_dict`, `cell_sets_dict`, and the set/data conversion methods
(`cell_sets_to_data`, `point_sets_to_data`, `cell_data_to_sets`,
`point_data_to_sets`).

## Tests

Tests live in [tests/](tests/) and mirror the upstream Python test suite, with
reference meshes under [tests/meshes/](tests/meshes/). Run them all from MATLAB:

```matlab
addpath('/path/to/meshio');
results = runtests('tests', 'IncludeSubfolders', false);
disp(table(results));
```
