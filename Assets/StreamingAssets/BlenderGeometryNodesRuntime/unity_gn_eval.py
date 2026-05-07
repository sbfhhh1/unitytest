import json
import sys
from pathlib import Path

import bpy


def log(message):
    print("[UnityGN] " + message, flush=True)


def load_request():
    if "--" not in sys.argv:
        raise RuntimeError("Missing request json path after --")
    request_path = Path(sys.argv[sys.argv.index("--") + 1])
    with request_path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def find_modifier(obj, modifier_name):
    if modifier_name:
        modifier = obj.modifiers.get(modifier_name)
        if modifier is not None:
            return modifier
    for modifier in obj.modifiers:
        if modifier.type == "NODES":
            return modifier
    raise RuntimeError(f"No Geometry Nodes modifier found on object '{obj.name}'")


def interface_identifier_by_name(node_group, socket_name):
    if not node_group or not socket_name:
        return None
    for item in node_group.interface.items_tree:
        if (
            getattr(item, "item_type", None) == "SOCKET"
            and getattr(item, "in_out", None) == "INPUT"
            and getattr(item, "name", None) == socket_name
        ):
            return getattr(item, "identifier", None)
    return None


def has_interface_inputs(node_group):
    if not node_group:
        return False
    for item in node_group.interface.items_tree:
        if getattr(item, "item_type", None) == "SOCKET" and getattr(item, "in_out", None) == "INPUT":
            return True
    return False


def group_input_socket_identifier_by_name(node_group, socket_name):
    if not node_group or not socket_name:
        return None
    for node in node_group.nodes:
        if node.bl_idname != "NodeGroupInput":
            continue
        for output in node.outputs:
            if output.name == socket_name:
                return getattr(output, "identifier", None)
    return None


def set_modifier_input(modifier, node_group, item):
    socket_name = item.get("name", "")
    fallback = item.get("fallbackIdentifier", "")
    value = item.get("value")
    existing_keys = set(modifier.keys())

    candidates = [
        interface_identifier_by_name(node_group, socket_name),
        group_input_socket_identifier_by_name(node_group, socket_name),
    ]
    if not any(candidates) and fallback and not has_interface_inputs(node_group):
        candidates.append(fallback)

    for key in candidates:
        if not key or key not in existing_keys:
            continue
        try:
            modifier[key] = value
            log(f"Set {socket_name or key} via {key} = {value}")
            return True
        except Exception:
            pass

    log(f"Warning: could not set GN input '{socket_name}'")
    return False


def remove_links_to_socket(node_group, socket):
    for link in list(node_group.links):
        if link.to_socket == socket:
            node_group.links.remove(link)


def try_apply_builtin_node_override(node_group, item):
    socket_name = item.get("name", "")
    if socket_name != "Hex Subdivisions":
        return False

    value = int(item.get("value", 3))
    value = max(1, min(3, value))
    changed = False
    for node in node_group.nodes:
        if node.bl_idname != "GeometryNodeMeshIcoSphere":
            continue
        socket = node.inputs.get("Subdivisions")
        if socket is None:
            continue
        # Blender 5.1 accepts a linked group input here but does not reliably
        # invalidate topology through the modifier socket. For runtime sidecar
        # evaluation, setting the node socket directly gives the expected mesh.
        remove_links_to_socket(node_group, socket)
        socket.default_value = value
        changed = True

    if changed:
        log(f"Set Hex Subdivisions by overriding Ico Sphere node sockets = {value}")
    return changed


def evaluated_mesh_to_cache(obj, output_path):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh(preserve_all_data_layers=True, depsgraph=depsgraph)
    try:
        mesh.calc_loop_triangles()
        vertices = []
        normals = []
        for vertex in mesh.vertices:
            co = vertex.co
            no = vertex.normal
            vertices.extend([co.x, co.y, co.z])
            normals.extend([no.x, no.y, no.z])

        triangles = []
        for tri in mesh.loop_triangles:
            triangles.extend([tri.vertices[0], tri.vertices[1], tri.vertices[2]])

        data = {
            "objectName": obj.name,
            "vertices": vertices,
            "normals": normals,
            "triangles": triangles,
        }

        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("w", encoding="utf-8") as handle:
            json.dump(data, handle, separators=(",", ":"))

        log(f"Exported {len(mesh.vertices)} vertices and {len(mesh.loop_triangles)} triangles to {output}")
    finally:
        evaluated.to_mesh_clear()


def main():
    request = load_request()
    object_name = request.get("objectName", "")
    obj = bpy.data.objects.get(object_name)
    if obj is None:
        available = ", ".join(sorted(bpy.data.objects.keys()))
        raise RuntimeError(f"Object '{object_name}' not found. Available objects: {available}")

    modifier = find_modifier(obj, request.get("modifierName", ""))
    node_group = modifier.node_group

    for item in request.get("inputs", []):
        if not try_apply_builtin_node_override(node_group, item):
            set_modifier_input(modifier, node_group, item)

    frame = int(request.get("frame", bpy.context.scene.frame_current))
    bpy.context.scene.frame_set(max(1, frame))
    bpy.context.view_layer.update()
    evaluated_mesh_to_cache(obj, request["outputPath"])


if __name__ == "__main__":
    main()
