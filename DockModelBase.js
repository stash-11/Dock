.pragma library

var DEFAULT_PINNED = []

var lastWrittenHash = null

var LAYOUT_OPTS = {
    slotWidth: 58,
    spacing: 8,
    iconSize: 50,
    hoverScale: 1.36,
    radius: 104,
    sidePadding: 18,
    separatorWidth: 14
}

function normalizeId(value) {
    var id = String(value || "").trim()
    return id.endsWith(".desktop") ? id.slice(0, -8) : id
}

// Combines the shell's app-library view with the desktop-entry index. The
// former may be ordered/fuzzy and may omit apps that have no open window;
// the latter is the complete set of entries Quickshell exposes. Earlier
// entries win so the app-library's richer metadata remains authoritative.
function mergeAppEntries(primary, secondary) {
    var result = []
    var seen = {}

    function append(source) {
        ;(source || []).forEach(function(row) {
            var entry = row && row.entry ? row.entry : row
            if (!entry) return
            var id = normalizeId(entry.id || entry.desktopId)
            if (!id || seen[id]) return

            var copy = {}
            for (var key in entry) copy[key] = entry[key]
            copy.id = id
            if (!copy.name) copy.name = copy.displayName || id
            if (!copy.icon) copy.icon = copy.iconName || copy.appIcon || ""

            seen[id] = true
            result.push(copy)
        })
    }

    append(primary)
    append(secondary)
    return result
}

function stripDesktop(value) { return normalizeId(value) }

function toArray(value) {
    if (Array.isArray(value)) return value
    if (value && Array.isArray(value.pinned)) return value.pinned
    return []
}

function parsePinned(text, fallback) {
    var source = String(text || "").trim()
    if (!source) return (fallback || DEFAULT_PINNED).slice()
    try {
        var parsed = JSON.parse(source)
        var values = toArray(parsed)
        var result = []
        values.forEach(function(value) {
            var id = normalizeId(value)
            if (id && result.indexOf(id) === -1) result.push(id)
        })
        return result
    } catch (error) {
        return (fallback || DEFAULT_PINNED).slice()
    }
}

function serializePinned(ids, order) {
    var clean = parsePinned(JSON.stringify(ids || []), [])
    var orderClean = []
    ;(order || []).forEach(function(value) {
        var id = normalizeId(value)
        if (id && orderClean.indexOf(id) === -1) orderClean.push(id)
    })
    return JSON.stringify({ version: 1, pinned: clean, order: orderClean }, null, 2) + "\n"
}

// Reads the persisted full dock order. The `order` field records the spatial
// layout (pinned and running interleaved); `pinned` records membership only.
// A legacy file without the field falls back to the caller's current order.
function parseOrder(text, fallback) {
    var source = String(text || "").trim()
    if (!source) return (fallback || []).slice()
    try {
        var parsed = JSON.parse(source)
        if (!parsed || !Array.isArray(parsed.order)) return (fallback || []).slice()
        var result = []
        parsed.order.forEach(function(value) {
            var id = normalizeId(value)
            if (id && result.indexOf(id) === -1) result.push(id)
        })
        return result
    } catch (error) {
        return (fallback || []).slice()
    }
}

function isPinned(ids, id) {
    return (ids || []).indexOf(normalizeId(id)) !== -1
}

function togglePinned(ids, id) {
    var next = (ids || []).slice()
    var value = normalizeId(id)
    var index = next.indexOf(value)
    if (index >= 0) next.splice(index, 1)
    else if (value) next.push(value)
    return next
}

function reorderPinned(ids, fromIndex, toIndex) {
    var next = (ids || []).slice()
    if (fromIndex < 0 || fromIndex >= next.length || toIndex < 0 || toIndex >= next.length)
        return next
    var item = next.splice(fromIndex, 1)[0]
    next.splice(toIndex, 0, item)
    return next
}

function insertPinned(ids, id, index) {
    var value = normalizeId(id)
    var next = (ids || []).slice()
    if (!value || next.indexOf(value) !== -1) return next
    var idx = Math.max(0, Math.min(index || 0, next.length))
    next.splice(idx, 0, value)
    return next
}

function removePinned(ids, id) {
    var value = normalizeId(id)
    var next = (ids || []).slice()
    var index = next.indexOf(value)
    if (index >= 0) next.splice(index, 1)
    return next
}

// Builds the visual order of items that flow through the dock. `floatingId`
// is the item being dragged (excluded from the flow; the ghost represents it),
// and `phantomIndex` (>= 0) inserts an empty placeholder slot anywhere in the
// full flow (pinned cluster followed by running unpinned apps) that shows
// where the dragged item will settle, so the gap tracks the cursor across the
// entire dock.
function buildFlow(pinned, runningUnpinned, floatingId, phantomIndex) {
    var flow = []
    var floating = normalizeId(floatingId)
    var hasPhantom = typeof phantomIndex === "number" && phantomIndex >= 0
    var combined = []

    ;(pinned || []).forEach(function(id) {
        var value = normalizeId(id)
        if (value !== floating) combined.push({ id: value })
    })
    ;(runningUnpinned || []).forEach(function(id) {
        var value = normalizeId(id)
        if (value !== floating) combined.push({ id: value })
    })

    var idx = hasPhantom ? Math.max(0, Math.min(phantomIndex, combined.length)) : -1
    for (var i = 0; i < combined.length; i++) {
        if (hasPhantom && i === idx) flow.push({ id: "__phantom__", phantom: true })
        flow.push(combined[i])
    }
    if (hasPhantom && idx === combined.length) flow.push({ id: "__phantom__", phantom: true })
    return flow
}

// Builds the session dock order: pinned apps first (persistent), then running
// apps that are not pinned, preserving their previous relative order so drag
// reorders survive window/app refreshes. Unknown apps append in list order.
function buildDockOrder(pinnedIds, runningIds, previousOrder) {
    var pinned = (pinnedIds || []).map(normalizeId)
    var running = (runningIds || []).map(normalizeId)
    var unpinned = []
    running.forEach(function(id) {
        if (pinned.indexOf(id) === -1 && unpinned.indexOf(id) === -1) unpinned.push(id)
    })
    var position = {}
    ;(previousOrder || []).forEach(function(id, index) { position[normalizeId(id)] = index })
    unpinned.sort(function(a, b) {
        var pa = position[a] === undefined ? 9999 : position[a]
        var pb = position[b] === undefined ? 9999 : position[b]
        return pa - pb
    })
    return pinned.concat(unpinned)
}

// Reconciles the session order against reality: keeps every app that is still
// pinned or running in its current position, appends newly pinned and newly
// running apps in order. This is what lets any app sit in any slot without
// being persisted.
function reconcileDockOrder(previousOrder, pinnedIds, runningIds) {
    var pinned = (pinnedIds || []).map(normalizeId)
    var running = (runningIds || []).map(normalizeId)
    var result = []
    ;(previousOrder || []).forEach(function(id) {
        var value = normalizeId(id)
        if (running.indexOf(value) !== -1 || pinned.indexOf(value) !== -1)
            result.push(value)
    })
    pinned.forEach(function(id) { if (result.indexOf(id) === -1) result.push(id) })
    running.forEach(function(id) { if (result.indexOf(id) === -1) result.push(id) })
    return result
}

// Moves an app to a new slot within the session order. Returns a new array.
function moveInOrder(order, id, index) {
    var value = normalizeId(id)
    var next = (order || []).slice()
    var from = next.indexOf(value)
    if (from < 0) {
        var idx = Math.max(0, Math.min(index || 0, next.length))
        next.splice(idx, 0, value)
        return next
    }
    next.splice(from, 1)
    var idx = Math.max(0, Math.min(index || 0, next.length))
    next.splice(idx, 0, value)
    return next
}

// Keeps only the pinned members of an order, in that order (used to persist
// pinned-app rearrangements without ever persisting running apps).
function orderPinned(order, pinnedIds) {
    var result = []
    ;(order || []).forEach(function(id) {
        var value = normalizeId(id)
        if ((pinnedIds || []).indexOf(value) !== -1 && result.indexOf(value) === -1)
            result.push(value)
    })
    return result
}

// Smooth pointer wave used by the dock. The cosine falloff keeps the hover
// response soft at both ends of the reach; the matching ramp is its integral,
// so neighboring slots move exactly far enough to make room for the growth.
function hoverFalloff(distance, reach) {
    var t = Math.abs(distance) / reach
    if (t >= 1) return 0
    return 0.5 * (1 + Math.cos(Math.PI * t))
}

function hoverRamp(distance, reach) {
    var u = distance / reach
    if (u >= 1) return 0.5
    if (u <= -1) return -0.5
    return 0.5 * u + Math.sin(Math.PI * u) / (2 * Math.PI)
}

// Sample a cosine wave against resting centers, then fan the scaled slots out
// around the hovered icon. The hovered center stays fixed; neighbors move only
// far enough to make room, which matches the macOS dock's local magnification.
function computeLayout(flow, cursorX, opts) {
    opts = opts || LAYOUT_OPTS
    var placements = {}
    var cursorValid = typeof cursorX === "number" && cursorX >= 0
    var reach = Math.max(opts.slotWidth, opts.radius)
    var restingWidth = 0
    var slots = []
    var centers = []
    for (var i = 0; i < flow.length; i++) {
        var item = flow[i]
        var slot = item.separator ? opts.separatorWidth : opts.slotWidth
        var center = restingWidth + slot / 2
        var scale = cursorValid && !item.separator
          ? 1 + (opts.hoverScale - 1) * hoverFalloff(center - cursorX, reach) : 1
        slots.push({ item: item, width: slot * scale, scale: scale })
        centers.push(center)
        restingWidth += slot + opts.spacing
    }
    restingWidth = Math.max(0, restingWidth - opts.spacing)

    if (cursorValid && slots.length) {
        var anchor = -1
        var nearest = Infinity
        for (var a = 0; a < slots.length; a++) {
            if (slots[a].item.separator) continue
            var distance = Math.abs(centers[a] - cursorX)
            if (distance < nearest) { nearest = distance; anchor = a }
        }
        if (anchor >= 0) {
            for (var left = anchor - 1; left >= 0; left--)
                centers[left] = centers[left + 1] - opts.spacing - (slots[left + 1].width + slots[left].width) / 2
            for (var right = anchor + 1; right < slots.length; right++)
                centers[right] = centers[right - 1] + opts.spacing + (slots[right - 1].width + slots[right].width) / 2
        }
    }

    // Keep the visual group centered in the fixed dock surface while retaining
    // the local fan spacing above. This avoids the whole row sliding when the
    // pointer crosses the dock, while preserving the centered macOS footprint.
    var visualLeft = 0
    var visualRight = restingWidth
    if (slots.length) {
        visualLeft = centers[0] - slots[0].width / 2
        visualRight = centers[centers.length - 1] + slots[slots.length - 1].width / 2
        var centerCorrection = restingWidth / 2 - (visualLeft + visualRight) / 2
        for (var c = 0; c < centers.length; c++) centers[c] += centerCorrection
        visualLeft += centerCorrection
        visualRight += centerCorrection
    }

    for (var j = 0; j < slots.length; j++) {
        var entry = slots[j]
        placements[entry.item.id] = {
          x: centers[j] - entry.width / 2, scale: entry.scale,
          // Bottom-origin scaling already raises the icon; no second lift.
          lift: 0, phantom: !!entry.item.phantom
        }
    }
    return { placements: placements, flowWidth: restingWidth,
      visualWidth: visualRight - visualLeft, totalWidth: restingWidth + 2 * opts.sidePadding }
}

// Drag insertion uses exactly the same slot centers as rendering.
function insertionIndexFor(cursorX, flow, opts) {
    opts = opts || LAYOUT_OPTS
    if (!flow || flow.length === 0) return 0
    var layout = computeLayout(flow, cursorX, opts)
    for (var i = 0; i < flow.length; i++) {
        var item = flow[i]
        var p = layout.placements[item.id]
        var slot = item.separator ? opts.separatorWidth : opts.slotWidth
        if (cursorX < p.x + slot * p.scale / 2) return i
    }
    return flow.length
}

function entryFor(id, entries) {
    var value = normalizeId(id)
    var list = entries || []
    var lowerValue = value.toLowerCase()
    for (var i = 0; i < list.length; i++) {
        var entry = list[i] && list[i].entry ? list[i].entry : (list[i] || {})
        var candidate = normalizeId(entry.id || entry.desktopId)
        if (candidate === value || candidate.toLowerCase() === lowerValue) return entry
    }
    var pretty = value.split(".").pop().replace(/[-_]+/g, " ").trim()
    if (pretty) pretty = pretty.charAt(0).toUpperCase() + pretty.slice(1)
    return { id: value, name: pretty || value, icon: "application-x-executable" }
}

function buildDockItems(pinned, entries, runningIds) {
    var result = []
    var running = runningIds || []
    ;(pinned || []).forEach(function(id) {
        var entry = entryFor(id, entries)
        result.push({ id: normalizeId(id), name: entry.name || entry.displayName || id,
            icon: entry.icon || entry.iconName || "", pinned: true,
            running: running.indexOf(normalizeId(id)) >= 0 })
    })

    var unpinned = []
    running.forEach(function(id) {
        var normalized = normalizeId(id)
        if (!isPinned(pinned, normalized) && unpinned.indexOf(normalized) === -1)
            unpinned.push(normalized)
    })
    unpinned.forEach(function(id) {
        var entry = entryFor(id, entries)
        result.push({ id: id, name: entry.name || entry.displayName || id,
            icon: entry.icon || entry.iconName || "", pinned: false, running: true })
    })
    return result
}

function hashContent(value) {
    var text = String(value || "")
    var hash = 0
    for (var i = 0; i < text.length; i++)
        hash = (Math.imul(31, hash) + text.charCodeAt(i)) | 0
    return hash
}

function shouldReprocess(content) {
    return hashContent(content) !== lastWrittenHash
}

function markWritten(content) { lastWrittenHash = hashContent(content) }

function resetWrittenGuard() { lastWrittenHash = null }

// ---- Dock settings (auto-hide, placement) ------------------------------
var lastSettingsHash = null

function normalizeSide(side) {
    var s = String(side || "bottom").toLowerCase()
    if (s === "left" || s === "right") return s
    return "bottom"
}

function boundedSetting(value, fallback, low, high) {
    return typeof value === "number" && isFinite(value)
      ? Math.max(low, Math.min(high, value)) : fallback
}

// Preserve arbitrary stack length; discard unknown or malformed cards.
function normalizeWidgets(value) {
    if (!Array.isArray(value)) return []
    return value.filter(function(card) {
        return card && ["music", "clock", "weather"].indexOf(card.type) !== -1
    }).map(function(card) {
        return { type: card.type, player: typeof card.player === "string" ? card.player : "" }
    })
}

function parseSettings(text, fallback) {
    var defaults = fallback || { autoHide: true, dockSide: "bottom" }
    var baseSide = normalizeSide(defaults.dockSide)
    var base = { appSpacing: Math.round(boundedSetting(defaults.appSpacing, 5, 0, 32)), dockScale: boundedSetting(defaults.dockScale, 0.9, 0.7, 1.4), widgets: normalizeWidgets(defaults.widgets), screenshotOutput: ["slurp", "copy", "save"].indexOf(defaults.screenshotOutput) !== -1 ? defaults.screenshotOutput : "slurp", autoHide: !!defaults.autoHide, dockSide: baseSide, appearanceMode: defaults.appearanceMode === "default" ? "default" : "theme", magnification: boundedSetting(defaults.magnification, 1.5, 1, 2.5), screenshotMagnification: boundedSetting(defaults.screenshotMagnification, boundedSetting(defaults.magnification, 1.5, 1, 2.5), 1, 2.5), transparency: boundedSetting(defaults.transparency, 0.11, 0, 1), roundness: boundedSetting(defaults.roundness, 0.3, 0, 1) }
    var source = String(text || "").trim()
    if (!source) return base
    try {
        var parsed = JSON.parse(source)
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            return base
        var out = { appSpacing: Math.round(boundedSetting(parsed.appSpacing, base.appSpacing, 0, 32)), dockScale: boundedSetting(parsed.dockScale, base.dockScale, 0.7, 1.4), widgets: parsed.widgets === undefined ? base.widgets : normalizeWidgets(parsed.widgets), screenshotOutput: ["slurp", "copy", "save"].indexOf(parsed.screenshotOutput) !== -1 ? parsed.screenshotOutput : base.screenshotOutput, autoHide: base.autoHide, dockSide: base.dockSide, appearanceMode: parsed.appearanceMode === "default" || parsed.appearanceMode === "theme" ? parsed.appearanceMode : base.appearanceMode, magnification: boundedSetting(parsed.magnification, base.magnification, 1, 2.5), screenshotMagnification: boundedSetting(parsed.screenshotMagnification, boundedSetting(parsed.magnification, base.screenshotMagnification, 1, 2.5), 1, 2.5), transparency: boundedSetting(parsed.transparency, base.transparency, 0, 1), roundness: boundedSetting(parsed.roundness, base.roundness, 0, 1) }
        if (typeof parsed.autoHide === "boolean") out.autoHide = parsed.autoHide
        else if (typeof parsed.autoHide === "string") out.autoHide = parsed.autoHide === "true"
        if (parsed.dockSide !== undefined) out.dockSide = normalizeSide(parsed.dockSide)
        return out
    } catch (error) {
        return base
    }
}

function serializeSettings(settings) {
    var value = settings && typeof settings.autoHide === "boolean" ? settings.autoHide : true
    var side = normalizeSide(settings && settings.dockSide)
    return JSON.stringify({ version: 1, appSpacing: Math.round(boundedSetting(settings && settings.appSpacing, 5, 0, 32)), dockScale: boundedSetting(settings && settings.dockScale, 0.9, 0.7, 1.4), widgets: normalizeWidgets(settings && settings.widgets), screenshotOutput: settings && ["slurp", "copy", "save"].indexOf(settings.screenshotOutput) !== -1 ? settings.screenshotOutput : "slurp", autoHide: value, dockSide: side, appearanceMode: settings && settings.appearanceMode === "default" ? "default" : "theme", magnification: boundedSetting(settings && settings.magnification, 1.5, 1, 2.5), screenshotMagnification: boundedSetting(settings && settings.screenshotMagnification, boundedSetting(settings && settings.magnification, 1.5, 1, 2.5), 1, 2.5), transparency: boundedSetting(settings && settings.transparency, 0.11, 0, 1), roundness: boundedSetting(settings && settings.roundness, 0.3, 0, 1) }, null, 2) + "\n"
}

function shouldReprocessSettings(content) {
    return hashContent(content) !== lastSettingsHash
}

function markSettingsWritten(content) { lastSettingsHash = hashContent(content) }

function resetSettingsGuard() { lastSettingsHash = null }

// ---- Auto-hide state machine (pure, testable) --------------------------
function shouldHideDock(state) {
    var s = state || {}
    var dockEngaged = !!(s.dockEngaged || s.dockHovered || s.edgeHovered)
    return !!(s.autoHide && s.enabled && s.dockReady && !s.autoHidden && !dockEngaged && !s.hideSuppressed)
}

function shouldScheduleHide(state) {
    var s = state || {}
    var dockEngaged = !!(s.dockEngaged || s.dockHovered || s.edgeHovered)
    return !!(s.autoHide && s.enabled && s.dockReady && !s.autoHidden && !dockEngaged && !s.hideSuppressed)
}

function shouldRevealDock(state) {
    var s = state || {}
    return !!(s.autoHide && s.enabled && s.autoHidden && !!s.edgeHovered)
}

// Allows the same pure module to be exercised by Node tests. QML does not
// define `module`, so this branch is inert when imported by Quickshell.
if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        normalizeWidgets: normalizeWidgets,
        DEFAULT_PINNED: DEFAULT_PINNED,
        LAYOUT_OPTS: LAYOUT_OPTS,
        normalizeId: normalizeId,
        mergeAppEntries: mergeAppEntries,
        stripDesktop: stripDesktop,
        toArray: toArray,
        parsePinned: parsePinned,
        parseOrder: parseOrder,
        serializePinned: serializePinned,
        isPinned: isPinned,
        togglePinned: togglePinned,
        reorderPinned: reorderPinned,
        insertPinned: insertPinned,
        removePinned: removePinned,
        buildFlow: buildFlow,
        buildDockOrder: buildDockOrder,
        reconcileDockOrder: reconcileDockOrder,
        moveInOrder: moveInOrder,
        orderPinned: orderPinned,
        computeLayout: computeLayout,
        insertionIndexFor: insertionIndexFor,
        entryFor: entryFor,
        buildDockItems: buildDockItems,
        hashContent: hashContent,
        shouldReprocess: shouldReprocess,
        markWritten: markWritten,
        resetWrittenGuard: resetWrittenGuard,
        parseSettings: parseSettings,
        serializeSettings: serializeSettings,
        normalizeSide: normalizeSide,
        shouldReprocessSettings: shouldReprocessSettings,
        markSettingsWritten: markSettingsWritten,
        resetSettingsGuard: resetSettingsGuard,
        shouldHideDock: shouldHideDock,
        shouldScheduleHide: shouldScheduleHide,
        shouldRevealDock: shouldRevealDock
    }
}
