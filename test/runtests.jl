using Linuxbrew
using Base.Test

# Print some debugging info
info("Using Linuxbrew.jl installed to $(Linuxbrew.prefix())")

# Restore pkg-config to its installed (or non-installed) state at the end of all of this
pkg_was_installed = Linuxbrew.installed("pkg-config")
hdf_was_installed = Linuxbrew.installed("homebrew/science/hdf5")

if pkg_was_installed
    info("Removing pkg-config for our testing...")
    Linuxbrew.rm("pkg-config")
end

# Add pkg-config
Linuxbrew.add("pkg-config")
@test Linuxbrew.installed("pkg-config") == true

# Print versioninfo() to boost coverage
Linuxbrew.versioninfo()

# Now show that we have it and that it's the right version
function strip_underscores(str)
    range = rsearch(str, "_")
    if range.start > 1
        return str[1:range.start-1]
    else
        return str
    end
end
pkgconfig = Linuxbrew.info("pkg-config")
version = readchomp(`pkg-config --version`)
@test version == strip_underscores(pkgconfig.version)
@test Linuxbrew.installed(pkgconfig) == true
info("$(pkgconfig) installed to: $(Linuxbrew.prefix(pkgconfig))")

@test isdir(Linuxbrew.prefix("pkg-config"))
@test isdir(Linuxbrew.prefix(pkgconfig))

# Run through some of the Linuxbrew API, both with strings and with BrewPkg objects
@test length(filter(x -> x.name == "pkg-config", Linuxbrew.list())) > 0
@test Linuxbrew.linked("pkg-config") == true
@test Linuxbrew.linked(pkgconfig) == true

# Test dependency inspection
@test Linuxbrew.direct_deps("pkg-config") == []
@test Linuxbrew.direct_deps(pkgconfig) == []
@test Linuxbrew.direct_deps("nettle") == [Linuxbrew.info("gmp")]
@test Linuxbrew.direct_deps(Linuxbrew.info("nettle")) == [Linuxbrew.info("gmp")]

# Run through our sorted deps routines, ensuring that everything is sorted
sortdeps = Linuxbrew.deps_sorted("pango")
for idx in 1:length(sortdeps)
    for dep in Linuxbrew.direct_deps(sortdeps[idx])
        depidx = findfirst(x -> (x.name == dep.name), sortdeps)
        @test depidx != 0
        @test depidx < idx
    end
end

# Test that we can probe for bottles properly
@test Linuxbrew.has_bottle("ack") == false
@test Linuxbrew.has_bottle("cairo") == true
# I will be a very happy man the day this test starts to fail
@test Linuxbrew.has_relocatable_bottle("cairo") == false
@test Linuxbrew.has_relocatable_bottle("staticfloat/juliadeps/libgfortran") == true
@test Linuxbrew.json(pkgconfig)["name"] == "pkg-config"

# Test that has_bottle knows which OSX version we're running on.
@test Linuxbrew.has_bottle("ld64") == false

# Test that we can translate properly
info("Translation should pass:")
@test Linuxbrew.translate_formula("gettext"; verbose=true) == "staticfloat/juliatranslated/gettext"
info("Translation should fail because it has no bottles:")
@test Linuxbrew.translate_formula("ack"; verbose=true) == "ack"

if hdf_was_installed
    # Remove hdf5 before we start messing around with it
    Linuxbrew.rm("homebrew/science/hdf5"; force=true)
end

# Make sure translation works properly with other taps
Linuxbrew.delete_translated_formula("Linuxbrew/science/hdf5"; verbose=true)
info("Translation should pass because we just deleted hdf5 from translation cache:")
@test Linuxbrew.translate_formula("Linuxbrew/science/hdf5"; verbose=true) == "staticfloat/juliatranslated/hdf5"
info("Translation should fail because hdf5 has already been translated:")
# Do it a second time so we can get coverage of practicing that particular method of bailing out
Linuxbrew.translate_formula(Linuxbrew.info("Linuxbrew/science/hdf5"); verbose=true)

# Test that installation of a formula from a tap when it's already been translated works
Linuxbrew.add("Linuxbrew/science/hdf5"; verbose=true)

if !hdf_was_installed
    Linuxbrew.rm("Linuxbrew/science/hdf5")
end

# Now that we have homebrew/science installed, test to make sure that prefix() works
# with taps properly:
@test Linuxbrew.prefix("metis4") == Linuxbrew.prefix("homebrew/science/metis4")

# Test more miscellaneous things
fontconfig = Linuxbrew.info("staticfloat/juliadeps/fontconfig")
@test Linuxbrew.formula_path(fontconfig) == joinpath(Linuxbrew.tappath, "fontconfig.rb")
@test !isempty(Linuxbrew.read_formula("xz"))
@test !isempty(Linuxbrew.read_formula(fontconfig))
info("add() should fail because this actually isn't a package name:")
@test_throws ArgumentError Linuxbrew.add("thisisntapackagename")

Linuxbrew.unlink(pkgconfig)
@test Linuxbrew.installed(pkgconfig) == true
@test Linuxbrew.linked(pkgconfig) == false
Linuxbrew.link(pkgconfig)
@test Linuxbrew.installed(pkgconfig) == true
@test Linuxbrew.linked(pkgconfig) == true

# Can't really do anything useful with these, but can at least run them to ensure they work
Linuxbrew.outdated()
Linuxbrew.update()
Linuxbrew.postinstall("pkg-config")
Linuxbrew.postinstall(pkgconfig)
Linuxbrew.delete_translated_formula("gettext"; verbose=true)
Linuxbrew.delete_all_translated_formulae(verbose=true)

# Test deletion as well, showing that the array-argument form continues on after errors
Linuxbrew.rm(pkgconfig)
Linuxbrew.add(pkgconfig)
info("rm() should fail because this isn't actually a package name:")
Linuxbrew.rm(["thisisntapackagename", "pkg-config"])
@test Linuxbrew.installed("pkg-config") == false
@test Linuxbrew.linked("pkg-config") == false

if pkg_was_installed
    info("Adding pkg-config back again...")
    Linuxbrew.add("pkg-config")
end
