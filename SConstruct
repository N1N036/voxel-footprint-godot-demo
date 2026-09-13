#!/usr/bin/env python

# Build Godot's C++ bindings once:  scons platform=windows target=template_debug
# This file is intentionally small so the experiment can stay focused on the
# octree selection logic in src/voxel_octree_demo.cpp.
env = SConscript("godot-cpp/SConstruct")
env.Append(CPPPATH=["src/"])

sources = Glob("src/*.cpp")
library_name = "bin/voxel_footprint{}{}".format(env["suffix"], env["SHLIBSUFFIX"])
library = env.SharedLibrary(library_name, sources)
Default(library)
