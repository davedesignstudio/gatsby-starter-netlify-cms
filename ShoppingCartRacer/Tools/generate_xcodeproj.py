#!/usr/bin/env python3
"""Generates App/ShoppingCartRacer.xcodeproj from the source tree.

The iOS target compiles the Swift package's sources directly (rather than through
a package dependency), so the game is one module and nothing in App/ needs to
import anything. That means the project has to list every source file, and a file
added to the package but not the project would silently fail to build. Generating
the project from the directory tree removes that drift entirely:

    python3 Tools/generate_xcodeproj.py

Re-run it after adding, removing or renaming a source file, and commit the result.
The identifiers are derived from paths, so regenerating an unchanged tree
produces a byte-identical project.
"""

from __future__ import annotations

import hashlib
import os
import re
import sys
from pathlib import Path

PROJECT_NAME = "ShoppingCartRacer"
BUNDLE_ID = "com.example.trolleytrophy"
DEPLOYMENT_TARGET = "16.0"
SWIFT_VERSION = "5.0"
MARKETING_VERSION = "1.0"

REPO_ROOT = Path(__file__).resolve().parent.parent
# The .xcodeproj lives in App/, so every path in the project is relative to it.
PROJECT_DIR = REPO_ROOT / "App"

# (group name, path relative to PROJECT_DIR)
SOURCE_ROOTS = [
    ("ShoppingCartRacer", "ShoppingCartRacer"),
    ("CartRacerKit", "../Sources/CartRacerKit"),
    ("CartRacerPresentation", "../Sources/CartRacerPresentation"),
]

SAFE_STRING = re.compile(r"^[A-Za-z0-9_./]+$")


def identifier(*parts: str) -> str:
    """A stable 24-character hex id, as Xcode uses."""
    digest = hashlib.md5("::".join(parts).encode("utf-8")).hexdigest()
    return digest[:24].upper()


def quote(value: str) -> str:
    if value == "":
        return '""'
    if SAFE_STRING.match(value):
        return value
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


class Node:
    """A group in the project navigator."""

    def __init__(self, name: str, path: str | None, parent_key: str):
        self.name = name
        self.path = path
        self.key = parent_key
        self.children: list[Node] = []
        self.files: list[tuple[str, str, str]] = []  # (name, file type, id)


def file_type(name: str) -> str:
    if name.endswith(".swift"):
        return "sourcecode.swift"
    if name.endswith(".plist"):
        return "text.plist.xml"
    if name.endswith(".xcassets"):
        return "folder.assetcatalog"
    if name.endswith(".md"):
        return "net.daringfireball.markdown"
    return "text"


def scan(directory: Path, group_name: str, key_prefix: str) -> Node:
    """Builds a group tree mirroring the directory, Swift files and catalogs only."""
    node = Node(group_name, None, identifier("group", key_prefix))

    entries = sorted(directory.iterdir(), key=lambda item: item.name)
    for entry in entries:
        if entry.name.startswith("."):
            continue
        relative = f"{key_prefix}/{entry.name}"
        if entry.is_dir():
            if entry.name.endswith(".xcassets"):
                node.files.append((entry.name, file_type(entry.name), identifier("file", relative)))
                continue
            child = scan(entry, entry.name, relative)
            child.path = entry.name
            # Skip directories that contain nothing we care about.
            if child.files or child.children:
                node.children.append(child)
        elif entry.suffix in {".swift", ".plist"}:
            node.files.append((entry.name, file_type(entry.name), identifier("file", relative)))

    return node


def collect(node: Node, accumulator: list[tuple[str, str, str]]) -> None:
    accumulator.extend(node.files)
    for child in node.children:
        collect(child, accumulator)


def emit_groups(node: Node, lines: list[str]) -> None:
    children = [child.key for child in node.children] + [file_id for _, _, file_id in node.files]
    lines.append(f"\t\t{node.key} /* {node.name} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for child in children:
        lines.append(f"\t\t\t\t{child},")
    lines.append("\t\t\t);")
    if node.path is not None:
        lines.append(f"\t\t\tpath = {quote(node.path)};")
        if node.path != node.name:
            lines.append(f"\t\t\tname = {quote(node.name)};")
    else:
        lines.append(f"\t\t\tname = {quote(node.name)};")
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
    for child in node.children:
        emit_groups(child, lines)


def build() -> str:
    if not PROJECT_DIR.exists():
        sys.exit(f"missing {PROJECT_DIR}")

    roots: list[Node] = []
    for group_name, relative_path in SOURCE_ROOTS:
        directory = (PROJECT_DIR / relative_path).resolve()
        if not directory.exists():
            sys.exit(f"missing source root {directory}")
        node = scan(directory, group_name, relative_path)
        node.path = relative_path
        roots.append(node)

    all_files: list[tuple[str, str, str]] = []
    for node in roots:
        collect(node, all_files)

    sources = [entry for entry in all_files if entry[1] == "sourcecode.swift"]
    resources = [entry for entry in all_files if entry[1] == "folder.assetcatalog"]
    if not sources:
        sys.exit("no Swift sources found")

    target_id = identifier("target", PROJECT_NAME)
    project_id = identifier("project", PROJECT_NAME)
    product_id = identifier("product", PROJECT_NAME)
    main_group_id = identifier("group", "root")
    products_group_id = identifier("group", "Products")
    sources_phase_id = identifier("phase", "sources")
    frameworks_phase_id = identifier("phase", "frameworks")
    resources_phase_id = identifier("phase", "resources")
    project_config_list_id = identifier("configlist", "project")
    target_config_list_id = identifier("configlist", "target")

    lines: list[str] = []
    lines.append("// !$*UTF8*$!")
    lines.append("{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tclasses = {")
    lines.append("\t};")
    lines.append("\tobjectVersion = 56;")
    lines.append(f"\trootObject = {project_id} /* Project object */;")
    lines.append("\tobjects = {")

    # PBXBuildFile
    lines.append("")
    lines.append("/* Begin PBXBuildFile section */")
    for name, kind, file_id in sources + resources:
        build_id = identifier("buildfile", file_id)
        lines.append(f"\t\t{build_id} /* {name} in Build Phase */ = {{isa = PBXBuildFile; fileRef = {file_id}; }};")
    lines.append("/* End PBXBuildFile section */")

    # PBXFileReference
    lines.append("")
    lines.append("/* Begin PBXFileReference section */")
    lines.append(
        f"\t\t{product_id} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; "
        f'explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; '
        "sourceTree = BUILT_PRODUCTS_DIR; };"
    )
    for name, kind, file_id in all_files:
        lines.append(
            f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {kind}; "
            f'path = {quote(name)}; sourceTree = "<group>"; }};'
        )
    lines.append("/* End PBXFileReference section */")

    # PBXFrameworksBuildPhase
    lines.append("")
    lines.append("/* Begin PBXFrameworksBuildPhase section */")
    lines.append(f"\t\t{frameworks_phase_id} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXFrameworksBuildPhase section */")

    # PBXGroup
    lines.append("")
    lines.append("/* Begin PBXGroup section */")
    lines.append(f"\t\t{main_group_id} = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for node in roots:
        lines.append(f"\t\t\t\t{node.key},")
    lines.append(f"\t\t\t\t{products_group_id},")
    lines.append("\t\t\t);")
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
    lines.append(f"\t\t{products_group_id} /* Products */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    lines.append(f"\t\t\t\t{product_id},")
    lines.append("\t\t\t);")
    lines.append("\t\t\tname = Products;")
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
    for node in roots:
        emit_groups(node, lines)
    lines.append("/* End PBXGroup section */")

    # PBXNativeTarget
    lines.append("")
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{target_id} /* {PROJECT_NAME} */ = {{")
    lines.append("\t\t\tisa = PBXNativeTarget;")
    lines.append(f"\t\t\tbuildConfigurationList = {target_config_list_id};")
    lines.append("\t\t\tbuildPhases = (")
    lines.append(f"\t\t\t\t{sources_phase_id},")
    lines.append(f"\t\t\t\t{frameworks_phase_id},")
    lines.append(f"\t\t\t\t{resources_phase_id},")
    lines.append("\t\t\t);")
    lines.append("\t\t\tbuildRules = (")
    lines.append("\t\t\t);")
    lines.append("\t\t\tdependencies = (")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tname = {PROJECT_NAME};")
    lines.append(f"\t\t\tproductName = {PROJECT_NAME};")
    lines.append(f"\t\t\tproductReference = {product_id};")
    lines.append('\t\t\tproductType = "com.apple.product-type.application";')
    lines.append("\t\t};")
    lines.append("/* End PBXNativeTarget section */")

    # PBXProject
    lines.append("")
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{project_id} /* Project object */ = {{")
    lines.append("\t\t\tisa = PBXProject;")
    lines.append("\t\t\tattributes = {")
    lines.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    lines.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    lines.append("\t\t\t\tLastUpgradeCheck = 1500;")
    lines.append("\t\t\t\tTargetAttributes = {")
    lines.append(f"\t\t\t\t\t{target_id} = {{")
    lines.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    lines.append("\t\t\t\t\t};")
    lines.append("\t\t\t\t};")
    lines.append("\t\t\t};")
    lines.append(f"\t\t\tbuildConfigurationList = {project_config_list_id};")
    lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    lines.append("\t\t\tdevelopmentRegion = en;")
    lines.append("\t\t\thasScannedForEncodings = 0;")
    lines.append("\t\t\tknownRegions = (")
    lines.append("\t\t\t\ten,")
    lines.append("\t\t\t\tBase,")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\tmainGroup = {main_group_id};")
    lines.append(f"\t\t\tproductRefGroup = {products_group_id};")
    lines.append('\t\t\tprojectDirPath = "";')
    lines.append('\t\t\tprojectRoot = "";')
    lines.append("\t\t\ttargets = (")
    lines.append(f"\t\t\t\t{target_id},")
    lines.append("\t\t\t);")
    lines.append("\t\t};")
    lines.append("/* End PBXProject section */")

    # PBXResourcesBuildPhase
    lines.append("")
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{resources_phase_id} /* Resources */ = {{")
    lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for name, _, file_id in resources:
        lines.append(f"\t\t\t\t{identifier('buildfile', file_id)} /* {name} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXResourcesBuildPhase section */")

    # PBXSourcesBuildPhase
    lines.append("")
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    lines.append(f"\t\t{sources_phase_id} /* Sources */ = {{")
    lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    for name, _, file_id in sources:
        lines.append(f"\t\t\t\t{identifier('buildfile', file_id)} /* {name} */,")
    lines.append("\t\t\t);")
    lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
    lines.append("/* End PBXSourcesBuildPhase section */")

    # XCBuildConfiguration
    project_common = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_WARN_DOCUMENTATION_COMMENTS", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("IPHONEOS_DEPLOYMENT_TARGET", DEPLOYMENT_TARGET),
        ("SDKROOT", "iphoneos"),
        ("SWIFT_VERSION", SWIFT_VERSION),
    ]
    debug_only = [
        ("DEBUG_INFORMATION_FORMAT", "dwarf"),
        ("ENABLE_TESTABILITY", "YES"),
        ("GCC_OPTIMIZATION_LEVEL", "0"),
        ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
        ("ONLY_ACTIVE_ARCH", "YES"),
        ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"),
        ("SWIFT_OPTIMIZATION_LEVEL", "-Onone"),
    ]
    release_only = [
        ("DEBUG_INFORMATION_FORMAT", '"dwarf-with-dsym"'),
        ("ENABLE_NS_ASSERTIONS", "NO"),
        ("MTL_ENABLE_DEBUG_INFO", "NO"),
        ("SWIFT_COMPILATION_MODE", "wholemodule"),
        ("SWIFT_OPTIMIZATION_LEVEL", '"-O"'),
        ("VALIDATE_PRODUCT", "YES"),
    ]
    target_common = [
        ("ASSETCATALOG_COMPILER_APPICON_NAME", "AppIcon"),
        ("ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME", "AccentColor"),
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", f"{PROJECT_NAME}/Info.plist"),
        ("LD_RUNPATH_SEARCH_PATHS", '(\n\t\t\t\t\t"$(inherited)",\n\t\t\t\t\t"@executable_path/Frameworks",\n\t\t\t\t)'),
        ("MARKETING_VERSION", MARKETING_VERSION),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
        ("PRODUCT_NAME", '"$(TARGET_NAME)"'),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("TARGETED_DEVICE_FAMILY", '"1,2"'),
    ]

    def emit_config(key: str, name: str, settings: list[tuple[str, str]]) -> None:
        lines.append(f"\t\t{key} /* {name} */ = {{")
        lines.append("\t\t\tisa = XCBuildConfiguration;")
        lines.append("\t\t\tbuildSettings = {")
        for setting, value in settings:
            lines.append(f"\t\t\t\t{setting} = {value};")
        lines.append("\t\t\t};")
        lines.append(f"\t\t\tname = {name};")
        lines.append("\t\t};")

    project_debug_id = identifier("config", "project", "Debug")
    project_release_id = identifier("config", "project", "Release")
    target_debug_id = identifier("config", "target", "Debug")
    target_release_id = identifier("config", "target", "Release")

    lines.append("")
    lines.append("/* Begin XCBuildConfiguration section */")
    emit_config(project_debug_id, "Debug", project_common + debug_only)
    emit_config(project_release_id, "Release", project_common + release_only)
    emit_config(target_debug_id, "Debug", target_common)
    emit_config(target_release_id, "Release", target_common)
    lines.append("/* End XCBuildConfiguration section */")

    # XCConfigurationList
    lines.append("")
    lines.append("/* Begin XCConfigurationList section */")
    for list_id, label, debug_id, release_id in [
        (project_config_list_id, f"Build configuration list for PBXProject {PROJECT_NAME}", project_debug_id, project_release_id),
        (target_config_list_id, f"Build configuration list for PBXNativeTarget {PROJECT_NAME}", target_debug_id, target_release_id),
    ]:
        lines.append(f"\t\t{list_id} /* {label} */ = {{")
        lines.append("\t\t\tisa = XCConfigurationList;")
        lines.append("\t\t\tbuildConfigurations = (")
        lines.append(f"\t\t\t\t{debug_id},")
        lines.append(f"\t\t\t\t{release_id},")
        lines.append("\t\t\t);")
        lines.append("\t\t\tdefaultConfigurationIsVisible = 0;")
        lines.append("\t\t\tdefaultConfigurationName = Release;")
        lines.append("\t\t};")
    lines.append("/* End XCConfigurationList section */")

    lines.append("\t};")
    lines.append("}")
    return "\n".join(lines) + "\n"


SCHEME_TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.7">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:{name}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:{name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
      <BuildableProductRunnable runnableDebuggingMode="0">
         <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_id}" BuildableName="{name}.app" BlueprintName="{name}" ReferencedContainer="container:{name}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration="Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES">
   </ArchiveAction>
</Scheme>
"""


def main() -> None:
    contents = build()
    project_path = PROJECT_DIR / f"{PROJECT_NAME}.xcodeproj"
    (project_path).mkdir(parents=True, exist_ok=True)
    (project_path / "project.pbxproj").write_text(contents, encoding="utf-8")

    schemes = project_path / "xcshareddata" / "xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    (schemes / f"{PROJECT_NAME}.xcscheme").write_text(
        SCHEME_TEMPLATE.format(target_id=identifier("target", PROJECT_NAME), name=PROJECT_NAME),
        encoding="utf-8",
    )

    swift_count = contents.count("sourcecode.swift")
    print(f"wrote {project_path.relative_to(REPO_ROOT)} ({swift_count} Swift files)")


if __name__ == "__main__":
    main()
