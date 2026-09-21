# Product Requirements Document (PRD) & Implementation Plan
## Disk Analysis (Modern Native macOS Disk Inventory Tool)

---

## 1. Executive Summary

**Disk Analysis** is a high-performance, native macOS utility designed as a modern reimagining of the classic **Disk Inventory X**. Built with Swift and SwiftUI, it delivers blazing-fast APFS volume analysis, interactive squarified cushion treemap visualization, and seamless macOS desktop integration (Quick Look, Trash, Reveal in Finder).

By default, the application targets the primary system data volume (`/System/Volumes/Data` or `/`) with single-click volume switching to external drives, USB storage, disk images, or arbitrary folders.

---

## 2. Goals & Key Objectives

1. **Speed & Scalability**: Scan hundreds of thousands of files across gigabytes/terabytes in seconds using parallel Darwin `getattrlistbulk` directory traversal without UI locking.
2. **Familiar Power with Modern UI**: Retain the proven 3-pane analytical power of Disk Inventory X (File Tree, Cushion Treemap, Smart Report) while modernizing with macOS HIG, Sonoma/Sequoia split views, and smooth animations.
3. **Cushion Treemap Fidelity**: Implement the iconic 3D cushion squarified treemap with color-coding by file extension, dynamic drill-down zooming, and bidirectional selection synchronization.
4. **Safety First**: Non-destructive, trash-first workflow (`NSWorkspace.shared.recycle`), confirmation dialogs with size estimates, and protected system path guards (`/System`, `/usr`, active app).
5. **Lightweight & Clean**: Built with Swift Package Manager (SPM) with zero `.xcodeproj` metadata bloat, runnable via CLI `swift run` or packaged into a standalone `DiskAnalysis.app`.

---

## 3. Architecture & Technical Design

### 3.1 Tech Stack
- **Language**: Swift 6 / modern Swift Concurrency (`async`/`await`, `actor`, `TaskGroup`).
- **UI Framework**: SwiftUI + AppKit bridging (`NSViewRepresentable`, `QLPreviewPanel`, `NSWorkspace`).
- **Graphics Engine**: SwiftUI `Canvas` with CoreGraphics / Metal shading for squarified cushion lighting.
- **Scanning Core**: Darwin C API `getattrlistbulk(2)` for low-overhead APFS catalog attribute streaming.
- **Build System**: Swift Package Manager (`Package.swift`) + standalone `.app` bundle synthesis script.

### 3.2 High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SwiftUI Application Shell                       │
│  (NavigationSplitView, Toolbar, Breadcrumbs, Volume Switcher, Search)   │
└───────────────┬────────────────────────┬───────────────────────────────┘
                │                        │
       Selection & Filter State  Live Stream Progress
                │                        │
┌───────────────▼────────────────────────▼───────────────────────────────┐
│                       AppState & Navigation Coordinator                │
├────────────────────────────────────────────────────────────────────────┤
│ • Root volume detection (Macintosh HD / Data, mounted volumes)         │
│ • Filter state (Search query, min-size threshold, bundle handling)     │
│ • Selection sync (Tree node <-> Treemap node)                         │
│ • Drill-down stack & breadcrumbs                                       │
└───────┬────────────────────────┬───────────────────────────────┬───────┘
        │                        │                               │
┌───────▼─────────────┐  ┌───────▼─────────────┐  ┌──────────────▼───────┐
│ File Hierarchy Tree │  │ Cushion Treemap     │  │ Smart Report         │
│ (Outline Table View)│  │ (Squarified Canvas) │  │ (Inspector Table)    │
└─────────────────────┘  └─────────────────────┘  └──────────────────────┘
        │                        │                               │
        └────────────────────────┼───────────────────────────────┘
                                 │
┌────────────────────────────────▼───────────────────────────────────────┐
│                   DiskScannerEngine (Parallel Darwin Core)             │
├────────────────────────────────────────────────────────────────────────┤
│ • getattrlistbulk(2) fast directory catalog walker                     │
│ • APFS block allocation calculation (st_blocks * 512 vs logical size)   │
│ • Package / Bundle detection (.app, .photoslibrary as atomic or folder)│
│ • Concurrent TaskGroup worker pool with live throughput throttling    │
│ • TCC / Permission error tracking and graceful skipping                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Feature Specifications

### 4.1 Volume & Target Selection
- **Default Target**: Auto-detects the boot volume's data mount (`/System/Volumes/Data` or `/`).
- **Volume Switcher**: Dropdown in the toolbar listing all mounted volumes (Internal SSD, External USB drives, DMGs, Network mounts) with capacity and usage bars.
- **Custom Folder**: "Choose Folder..." dialog allowing focused analysis of specific paths (e.g., `~/Downloads`, `~/Library`, `/var`).

### 4.2 High-Performance Scanner
- **Bulk Directory Traversal**: Uses `getattrlistbulk(2)` to retrieve file names, attributes, object IDs, physical block counts, and dates directly in batches.
- **Physical vs. Logical Size**: Correctly accounts for allocated disk space (`st_blocks * 512`), APFS sparse files, and avoids double-counting hard links.
- **Package Bundle Handling**: Configurable toggle to treat macOS Application (`.app`), photo libraries (`.photoslibrary`), and frameworks as atomic single items or transparent folders.
- **Live Progress**: Displays scanned file count, elapsed time, current directory being examined, and live throughput (files/sec).

### 4.3 3-Pane Analytical Layout
1. **Left Pane — File Hierarchy Tree**:
   - Hierarchical outline table displaying file/folder name, icon, size (formatted with auto KB/MB/GB/TB), percentage of parent volume, item count, and modification date.
   - Sortable by size (default), name, or date.
2. **Center / Bottom — Interactive Cushion Treemap**:
   - Squarified treemap algorithm ensuring rectangular aspect ratios near 1.0 (golden ratio / squares).
   - Iconic 3D cushion shading (bump map surface equation reflecting depth in folder hierarchy).
   - Colored by file extension based on the File Kinds palette.
   - Double-click to zoom into a directory; breadcrumb bar on top to navigate up.
   - Hover inspector displaying file name, path, physical size, and kind.
3. **Right Pane — Smart Report**:
   - List files larger than 1 GB, sorted by size.
   - List conservative review candidates such as caches, temporary files, backups, and large archives.
   - Click an item to reveal it in Finder.
   - Right-click an item for Reveal in Finder, Open, Copy Path, Get Info, and Move to Trash.

### 4.4 File Operations & Safety
- **Quick Look**: Pressing `Spacebar` on any selected item opens native macOS `QLPreviewPanel`.
- **Reveal in Finder**: `Cmd+R` or context menu opens the item in Finder.
- **Move to Trash**: `Cmd+Backspace` safely moves the file/folder to Trash via `NSWorkspace.shared.recycle`.
  - Displays confirmation dialog showing total size to be freed and file count.
  - Automatically subtracts freed space and updates the live tree and treemap without a full rescan.
- **System Protection Safeguards**: Prevents trashing root mount points, `/System`, `/usr`, `/bin`, `/sbin`, or the running application itself.

### 4.5 Filtering & Search
- **Search Bar**: Instant real-time filter by name or extension in the toolbar.
- **Size Threshold**: Quick filter presets (e.g., "All", "> 100 MB", "> 1 GB", "> 10 GB") to spot space hogs immediately.

---

## 5. Phases & Actionable Checklist

### Phase 1: Foundation & High-Performance Scanner Engine
- [x] **1.1 Project Scaffolding**: Setup `Package.swift` for a native macOS 14+ / Swift 6 application.
- [x] **1.2 Data Models**: Define `FileNode`, `FileKind`, `VolumeInfo`, and `ScanStatistics`.
- [x] **1.3 Darwin Bulk Traversal**: Implement `DarwinScanner` utilizing `getattrlistbulk(2)` to batch read directory attributes without individual `stat` overhead.
- [x] **1.4 Sizing & Block Math**: Implement physical block allocation calculation (`st_blocks * 512`) with APFS sparse file awareness.
- [x] **1.5 Concurrency & Progress**: Build `DiskScannerEngine` with Swift concurrency (`TaskGroup` worker pool), live progress stream (files/sec, scanned count, current path), and cancel token.
- [x] **1.6 Package Bundle Detection**: Implement detection for macOS bundles (`.app`, `.photoslibrary`, etc.) with user toggle.
- [x] **1.7 Unit & Benchmark Tests**: Create tests validating file tree assembly, size calculations, and scan performance against test directories.

### Phase 2: Treemap Layout Algorithm & Cushion Renderer
- [x] **2.1 Squarified Layout Algorithm**: Implement the Bruls-Huizing-van Wijk squarified treemap layout generator in Swift.
- [x] **2.2 Cushion Shading Engine**: Implement the van Wijk & van de Wetering cushion bump-mapping algorithm to calculate ridge heights and surface normals for 3D cushion effect.
- [x] **2.3 Extension Color Palette**: Implement deterministic color hashing and distinct palette assigner for file kinds (e.g., video, audio, archive, application, code, documents).
- [x] **2.4 Hit-Testing & Hover**: Build efficient spatial lookup (quadtree or binary rect bounds search) for mouse hover and click detection.
- [x] **2.5 Drill-Down & Zooming**: Support navigating into child folders as treemap root with smooth transition animations and parent breadcrumb stack.

### Phase 3: Modern 3-Pane SwiftUI Interface & Selection Sync
- [x] **3.1 Main Window Shell**: Implement `NavigationSplitView` with customizable split proportions and macOS toolbar.
- [x] **3.2 File Hierarchy Tree View**: Implement collapsible outline table with sorting, system file icons (`NSWorkspace.shared.icon`), human-readable sizes, and percentage bars.
- [x] **3.3 Treemap View Container**: Embed the cushion treemap Canvas with responsive resize, zoom gestures, and hover HUD tooltip.
- [x] **3.4 Smart Report**: Build a right-hand report listing large files and conservative cleanup candidates with Finder and file actions.
- [x] **3.5 Bidirectional Selection Sync**:
  - Selecting an item in the Tree highlights the rectangle in the Treemap.
  - Clicking a rectangle in the Treemap reveals and selects the item in the Tree.
  - Smart Report items reveal their matching files in Finder and expose the same context menu as the tree.

### Phase 4: Volume Management, Filters, and Search
- [x] **4.1 Boot & Volume Discovery**: Implement `VolumeManager` using `FileManager.mountedVolumeURLs` to identify boot data volume (`/System/Volumes/Data`) and external drives.
- [x] **4.2 Volume Picker UI**: Add toolbar picker displaying volume name, icon, total capacity, and free space gauge.
- [x] **4.3 Custom Directory Picker**: Implement standard `NSOpenPanel` for arbitrary folder selection.
- [x] **4.4 Real-Time Search**: Implement instant filename and extension filter with matching visual highlights.
- [x] **4.5 Size Threshold Filters**: Add threshold selector (`All`, `>100MB`, `>1GB`, `>5GB`) to quickly isolate major disk consumers.

### Phase 5: File Operations, Quick Look, Trash Safety, & Packaging
- [x] **5.1 Quick Look Integration**: Implement `QLPreviewPanelDataSource` / AppKit responder bridge for Spacebar preview of selected files.
- [x] **5.2 Context Menus**: Contextual menu on Tree and Treemap nodes (Reveal in Finder, Open, Quick Look, Copy Path, Move to Trash).
- [x] **5.3 Safe Trash Recycling**: Wire `Cmd+Backspace` and menu to `NSWorkspace.shared.recycle` with modal confirmation dialog.
- [x] **5.4 System Protection Safeguards**: Enforce guardrails disallowing deletion of critical OS mount points and files.
- [x] **5.5 Live Tree Pruning**: Incrementally update tree and recompute parent sizes upon trashing without requiring a full re-scan.
- [x] **5.6 Standalone App Bundle Packaging**: Create `scripts/build_app.sh` to package SPM build output into a signed, ready-to-run `DiskAnalysis.app` with `Info.plist` and app icon.

### Phase 6: Verification, Polish, and Documentation
- [x] **6.1 Stress & Large Volume Testing**: Verify on large directories (e.g. `~/Library`, `/Applications`, or main drive data volume).
- [x] **6.2 Memory & CPU Profiling**: Ensure scanner and treemap rendering maintain low memory footprint without memory leaks.
- [x] **6.3 Permission / TCC Handling**: Verify graceful skipping of unreadable directories and non-intrusive Full Disk Access guidance.
- [x] **6.4 User Documentation**: Provide comprehensive `README.md` with usage guide, shortcuts, and architecture breakdown.
