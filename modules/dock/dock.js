.pragma library

// Pinned-app order for the dock.

// Move `id` to the position `targetId` has now (what dragging an icon onto another one does). Returns a new list;
// the same list when either id is missing or they are the same.
function reorder(ids, id, targetId) {
    const from = ids.indexOf(id), to = ids.indexOf(targetId)
    if (from < 0 || to < 0 || from === to) return ids
    const out = ids.slice()
    out.splice(from, 1)
    out.splice(to, 0, id)
    return out
}
