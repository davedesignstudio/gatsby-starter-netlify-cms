#!/usr/bin/env python3
"""Checks the generated Xcode project without needing Xcode.

Run after `generate_xcodeproj.py`:

    pip install pbxproj
    python3 Tools/validate_xcodeproj.py

It parses `project.pbxproj` with a real OpenStep plist parser (so a malformed
project is caught rather than discovered by a developer on a Mac), then verifies:

  * every file reference resolves to a file that exists on disk
  * every Swift file in the package and app source trees is in the Sources phase
  * the asset catalog is in the Resources phase
  * the target has the build settings the app needs to launch
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    from pbxproj import XcodeProject
except ImportError:  # pragma: no cover
    sys.exit("pbxproj is required: pip install pbxproj")

REPO_ROOT = Path(__file__).resolve().parent.parent
PROJECT_DIR = REPO_ROOT / "App"
PBXPROJ = PROJECT_DIR / "ShoppingCartRacer.xcodeproj" / "project.pbxproj"

SOURCE_TREES = [
    REPO_ROOT / "App" / "ShoppingCartRacer",
    REPO_ROOT / "Sources" / "CartRacerKit",
    REPO_ROOT / "Sources" / "CartRacerPresentation",
]

REQUIRED_SETTINGS = {
    "INFOPLIST_FILE": "ShoppingCartRacer/Info.plist",
    "PRODUCT_BUNDLE_IDENTIFIER": "com.example.trolleytrophy",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
}


def resolve_path(project: XcodeProject, file_id: str) -> str:
    """Walks up the group tree to build a file's path on disk."""
    groups = list(project.objects.get_objects_in_section("PBXGroup"))
    segments: list[str] = []
    current = file_id
    visited: set[str] = set()

    while True:
        node = project.objects[current]
        path = getattr(node, "path", None)
        if path:
            segments.append(path)
        owner = next((group for group in groups if current in (group.children or [])), None)
        if owner is None:
            break
        owner_id = owner.get_id()
        if owner_id in visited:
            break
        visited.add(owner_id)
        current = owner_id

    return os.path.normpath(os.path.join(str(PROJECT_DIR), *reversed(segments)))


def main() -> None:
    if not PBXPROJ.exists():
        sys.exit(f"missing {PBXPROJ}; run Tools/generate_xcodeproj.py")

    project = XcodeProject.load(str(PBXPROJ))
    failures: list[str] = []

    targets = project.objects.get_targets()
    if len(targets) != 1:
        failures.append(f"expected exactly one target, found {len(targets)}")
    target = targets[0]

    # File references must point at real files.
    referenced_swift: set[str] = set()
    asset_catalogs: set[str] = set()
    for obj in list(project.objects.get_objects_in_section("PBXFileReference")):
        if getattr(obj, "sourceTree", None) == "BUILT_PRODUCTS_DIR":
            continue
        full = resolve_path(project, obj.get_id())
        if not os.path.exists(full):
            failures.append(f"reference to a file that does not exist: {obj.path} -> {full}")
            continue
        if str(obj.path).endswith(".swift"):
            referenced_swift.add(os.path.realpath(full))
        if str(obj.path).endswith(".xcassets"):
            asset_catalogs.add(os.path.realpath(full))

    # Every Swift file on disk must be referenced, or it silently would not build.
    on_disk: set[str] = set()
    for tree in SOURCE_TREES:
        if not tree.exists():
            failures.append(f"missing source tree {tree}")
            continue
        for path in tree.rglob("*.swift"):
            on_disk.add(os.path.realpath(str(path)))

    for missing in sorted(on_disk - referenced_swift):
        failures.append(f"Swift file not in the project: {missing}")
    for extra in sorted(referenced_swift - on_disk):
        failures.append(f"project references a Swift file outside the source trees: {extra}")

    # Build phases.
    phases = {project.objects[phase].isa: project.objects[phase] for phase in target.buildPhases}
    if "PBXSourcesBuildPhase" not in phases:
        failures.append("target has no Sources build phase")
    else:
        compiled = set()
        for build_file_id in phases["PBXSourcesBuildPhase"].files or []:
            build_file = project.objects[build_file_id]
            compiled.add(os.path.realpath(resolve_path(project, build_file.fileRef)))
        for missing in sorted(on_disk - compiled):
            failures.append(f"Swift file not compiled by the target: {missing}")

    if "PBXResourcesBuildPhase" not in phases:
        failures.append("target has no Resources build phase")
    else:
        bundled = set()
        for build_file_id in phases["PBXResourcesBuildPhase"].files or []:
            build_file = project.objects[build_file_id]
            bundled.add(os.path.realpath(resolve_path(project, build_file.fileRef)))
        for catalog in asset_catalogs:
            if catalog not in bundled:
                failures.append(f"asset catalog is not in the Resources phase: {catalog}")

    # Build settings on both configurations.
    configuration_list = project.objects[target.buildConfigurationList]
    for configuration_id in configuration_list.buildConfigurations:
        configuration = project.objects[configuration_id]
        settings = configuration.buildSettings
        for key, expected in REQUIRED_SETTINGS.items():
            actual = str(settings.get(key, "")).strip('"')
            if actual != expected:
                failures.append(f"{configuration.name}: {key} is {actual!r}, expected {expected!r}")

    if failures:
        print(f"{len(failures)} problem(s) found:")
        for failure in failures:
            print(f"  - {failure}")
        sys.exit(1)

    print(f"project is valid: {len(on_disk)} Swift files compiled, {len(asset_catalogs)} asset catalog(s) bundled")


if __name__ == "__main__":
    main()
