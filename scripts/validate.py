#!/usr/bin/env python3
"""Structural validation only. This does not substitute for Xcode typechecking or device tests."""
from __future__ import annotations
import json
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
IGNORE = {".build", ".git", ".swiftpm", "__pycache__"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def inspect_project(manifest: dict) -> None:
    project = ROOT / "Shelf.xcodeproj/project.pbxproj"
    require(project.exists(), "Missing Xcode project.")
    tool = shutil.which("plutil")
    if not tool:
        print("NOTE: plutil unavailable; deep project parsing skipped.")
        return
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / "project.json"
        subprocess.run([tool, "-convert", "json", "-o", str(output), "--", str(project)], check=True, capture_output=True)
        data = json.loads(output.read_text())
    objects = data["objects"]
    root = objects[data["rootObject"]]
    require(root["isa"] == "PBXProject", "Invalid project root.")
    targets = [objects[key] for key in root["targets"]]
    require(sorted(target["name"] for target in targets) == sorted(manifest["targets"]), "Target list mismatch.")
    for key, obj in objects.items():
        for field in ["buildConfigurationList", "mainGroup", "productRefGroup", "fileRef", "productReference", "target", "targetProxy"]:
            if field in obj:
                require(obj[field] in objects, f"Dangling {field} reference in {key}.")
        for field in ["children", "files", "buildPhases", "buildConfigurations", "dependencies", "packageProductDependencies", "packageReferences"]:
            for reference in obj.get(field, []):
                require(reference in objects, f"Dangling {field} entry in {key}.")
        if obj["isa"] == "XCRemoteSwiftPackageReference":
            require(obj.get("repositoryURL") == "https://github.com/microsoft/onnxruntime-swift-package-manager.git",
                    "Unexpected remote dependency added.")
            requirement = obj.get("requirement", {})
            require(requirement.get("version") == "1.24.2" and requirement.get("kind") == "exactVersion",
                    "ONNX Runtime dependency must remain exactly pinned to 1.24.2.")
    groups = {key: obj for key, obj in objects.items() if obj["isa"] in ["PBXGroup", "PBXVariantGroup"]}
    parents = {child: key for key, obj in groups.items() for child in obj.get("children", [])}

    def path_for(key: str) -> Path:
        obj = objects[key]
        parent = parents.get(key)
        base = path_for(parent) if parent and obj.get("sourceTree") == "<group>" else ROOT
        return base / obj.get("path", "")

    actual_sources: set[str] = set()
    for obj in objects.values():
        if obj["isa"] != "PBXSourcesBuildPhase":
            continue
        phase_sources: set[str] = set()
        for build_id in obj["files"]:
            reference = objects[build_id]["fileRef"]
            path = path_for(reference)
            require(path.is_file(), f"Source reference not found: {path}")
            relative = str(path.relative_to(ROOT))
            require(relative not in phase_sources, f"Duplicate source input in one target: {relative}")
            phase_sources.add(relative)
            actual_sources.add(relative)
    expected = set(manifest["appSources"] + manifest["unitTestSources"] + manifest["uiTestSources"])
    require(actual_sources == expected, "Native source build phase membership differs from manifest.")
    for obj in objects.values():
        if obj["isa"] == "PBXFileReference" and obj.get("sourceTree") != "BUILT_PRODUCTS_DIR":
            key = next(k for k, v in objects.items() if v is obj)
            require(path_for(key).exists(), f"Missing project file: {path_for(key)}")
    scheme = ET.parse(ROOT / "Shelf.xcodeproj/xcshareddata/xcschemes/Shelf.xcscheme")
    for reference in scheme.iter("BuildableReference"):
        require(reference.attrib["BlueprintIdentifier"] in objects, "Scheme references a missing target.")
    print(f"PASS: {len(objects)} project objects; source and scheme references resolve.")


def main() -> int:
    try:
        files = [p for p in ROOT.rglob("*") if p.is_file() and not IGNORE.intersection(p.relative_to(ROOT).parts)]
        sources = [p for p in files if p.suffix in {".swift", ".sh", ".py", ".command"}]
        sizes = [(len(p.read_text().splitlines()), str(p.relative_to(ROOT))) for p in sources]
        for lines, path in sizes:
            require(lines <= 300, f"God-file boundary exceeded: {path} ({lines} lines)")
        manifest = json.loads((ROOT / "evidence/project-manifest.json").read_text())
        for key, folder in [("appSources", "Shelf"), ("unitTestSources", "ShelfTests"), ("uiTestSources", "ShelfUITests")]:
            expected = {str(p.relative_to(ROOT)) for p in (ROOT / folder).rglob("*.swift")}
            require(expected == set(manifest[key]), f"Update native target membership/inventory: {key}")
        for resource in manifest["resources"]:
            require((ROOT / resource).exists(), f"Missing resource: {resource}")
        for path in files:
            if path.suffix in {".plist", ".xcprivacy"}:
                plistlib.loads(path.read_bytes())
            if path.suffix == ".json":
                json.loads(path.read_text())
            if path.suffix in {".xcscheme", ".xcworkspacedata"}:
                ET.parse(path)
        for path in (ROOT / "Packages/ShelfCore/Sources").rglob("*.swift"):
            require(not re.search(r"^import (SwiftUI|UIKit|PDFKit|Observation)$", path.read_text(), re.M), f"UI leak into core: {path}")
        package = (ROOT / "Packages/ShelfCore/Package.swift").read_text()
        require(".package(url:" not in package, "Unexpected external Swift dependency.")
        inspect_project(manifest)
        print(f"PASS: {len(sources)} source/script files; largest {max(sizes)[0]} lines ({max(sizes)[1]}).")
        print("PASS: assets, plist/JSON/XML, local package and native membership checks.")
        print("NOT CHECKED: Apple SDK typechecking, native runtime, performance, or physical installation.")
        return 0
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, ET.ParseError) as error:
        print(f"Structural validation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
