#!/usr/bin/env python3
"""Render the production SwiftUI rig offscreen on macOS, without a Simulator.

Uses real production source blocks, not a second drawing implementation. The
result is visual reference evidence; the iOS app still needs its Debug compile.
"""

import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/brand/native-renders"


def block(source: str, marker: str) -> str:
    start = source.index(marker)
    brace = source.index("{", start)
    depth, end = 1, brace + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


motion = (ROOT / "testMugshot/Design/MugshotMotionSystem.swift").read_text()
subset = "import SwiftUI\n" + "\n".join(block(motion, marker) for marker in ["enum MugshotMotion {", "enum MugshotDrinkAppearance:", "extension Comparable {"])
paths = [
    "testMugshot/Design/BrandColors.swift",
    "testMugshot/Design/MugsyDesignSystem.swift",
    "testMugshot/Design/MugsyPoseCatalog.swift",
    "testMugshot/Views/Components/MugsyModelView.swift",
    "testMugshot/Views/Components/MugsyExpandedAccessoryView.swift",
]
OUTPUT.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="mugshot-rig-render-") as directory:
    temporary = Path(directory)
    sources = []
    fingerprints = {}
    for path in paths:
        data = (ROOT / path).read_bytes()
        fingerprints[path] = hashlib.sha256(data).hexdigest()
        destination = temporary / Path(path).name
        destination.write_text(data.decode().split("\n#Preview", 1)[0])
        sources.append(str(destination))
    helper = temporary / "ProductionMotionSubset.swift"
    helper.write_text(subset)
    fingerprints["productionMotionSubset"] = hashlib.sha256(subset.encode()).hexdigest()
    sources.append(str(helper))
    entry = temporary / "Export.swift"
    entry.write_text('''import AppKit
import SwiftUI

@main
struct MugsyRigExport {
    @MainActor
    static func main() throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1])
        for pose in MugsyCatalogPose.allCases where pose.specificationID == CommandLine.arguments[2] {
            let content = MugsyModelView(configuration: pose.configuration)
                .frame(width: 500, height: 500)
                .environment(\\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.proposedSize = ProposedViewSize(width: 500, height: 500)
            renderer.scale = 1
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                fatalError("Could not render " + pose.rawValue)
            }
            try png.write(to: destination.appendingPathComponent(pose.specificationID + ".png"))
        }
        print("Rendered " + CommandLine.arguments[2] + " from production SwiftUI source.")
    }
}
''')
    sources.append(str(entry))
    executable = temporary / "mugsy-export"
    subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-target", "arm64-apple-macos14.0", *sources, "-o", str(executable)], check=True)
    # A fresh graph per process avoids stale offscreen GraphicsContext resources
    # between ImageRenderer instances; this is an export concern, not app state.
    pose_ids = sys.argv[1:] or [pose["id"] for pose in json.loads((ROOT / "docs/brand/identity/mugsy-spec.json").read_text())["poses"]]
    for pose_id in pose_ids:
        subprocess.run([str(executable), str(OUTPUT), pose_id], check=True)
records = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(OUTPUT.glob("*.png"))}
(OUTPUT / "manifest.json").write_text(json.dumps({"kind": "production SwiftUI offscreen render", "platform": "macOS reference; not an iOS runtime acceptance", "source_sha256": fingerprints, "renders": records}, indent=2) + "\n")
