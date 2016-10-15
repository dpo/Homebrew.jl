# This file contains the necessary ingredients to create a PackageManager for BinDeps
using BinDeps
import BinDeps: PackageManager, can_use, package_available, libdir, generate_steps, LibraryDependency, provider
import Base: show

type LB <: PackageManager
    packages
end

show(io::IO, lb::LB) = write(io, "Linuxbrew Bottles ",
    join(isa(lb.packages, AbstractString) ? [lb.packages] : lb.packages,", "))



# Only return true on Linux platforms
can_use(::Type{LB}) = Compat.KERNEL == :Linux

function package_available(p::LB)
    !can_use(LB) && return false
    pkgs = p.packages
    if isa(pkgs, AbstractString)
        pkgs = [pkgs]
    end

    # For each package, see if we can get info about it.  If not, fail out
    for pkg in pkgs
        try
            info(pkg)
        catch
            return false
        end
    end
    return true
end

libdir(p::LB, dep) = joinpath(brew_prefix, "lib")

provider{T<:AbstractString}(::Type{LB}, packages::Vector{T}; opts...) = LB(packages)

function generate_steps(dep::LibraryDependency, p::LB, opts)
    pkgs = p.packages
    if isa(pkgs, AbstractString)
        pkgs = [pkgs]
    end
    ()->install(pkgs)
end

function install(pkgs)
    for pkg in pkgs
        add(pkg)
    end
end
