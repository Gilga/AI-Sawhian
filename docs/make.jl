@info "Creating Docs started..."

# required
using Pkg

# helper 
function install_pkgs(pkgs;extern=true)
  pkg_list = Pkg.installed()

  for (pkg_name,use) in pkgs
    pkg_symbol = Symbol(pkg_name)
    
    if extern && !haskey(pkg_list,pkg_name)
      @info "Install $pkg_name..."
      @eval Pkg.add($pkg_name)
    end
    
    if use @eval using $pkg_symbol end
    
    @info "$pkg_symbol is ready"
    #exit(0)# exit, cannot create documentations!
  end
end

# setup paths
@info "Setup paths..."
root = joinpath(@__DIR__,"../")
source = joinpath(root,"src/")
docs = @__DIR__
docs_source = joinpath(docs, "src/")

push!(LOAD_PATH,root)
push!(LOAD_PATH,source)

# ckeck folder
if !isdir(docs_source) mkdir(docs_source) end # create folder "docs/src/" if dont exists

# install packages
@info "Install packages..."
pkgs = (x->(x,false)).(readlines(joinpath(root,"REQUIRE")))
push!(pkgs, ("Documenter",true)) # add Documenter
install_pkgs(pkgs)
Pkg.update()

# include package
@info "Include custom packages..."
install_pkgs((x->(x,true)).(["sawhian", "Client"]);extern=false)

# read files
@info "Create md files..."
srcfiles = joinpath(docs_source, "files/")
md_source_files = String[]
md_modules = String[]

for (root, dirs, files) in walkdir(source)
    #for dir in dirs
    #    println(joinpath(root, dir)) # path to directories
    #end
    @info "Read $root..."
    for file in files
        path = joinpath(root, file)
        ext = last(splitext(file))
        if ext != ".jl" continue end
        name = replace(file,ext=>"")
        mdfile = name*".md"
        mdpath = joinpath(srcfiles, mdfile)
        
        @info "Read $file..."
        content = open(path) do f; read(f, String); end
        
        content = replace(content,"\r"=>"")
        content = replace(content,r"\#[^\n]+\n?"=>"")
        #content = replace(content,r"\#\=.*\=\#"=>"")
        
        hasmodule = match(r"module\s+([^\n\;]+)",content)
        modname = hasmodule == nothing ? "" : hasmodule.captures[1]*"."

        content = replace(content,r"([^\s\(]+\([^\)]*\)\s+\=)"=>s"function \1")
        
        functions = ""
        for m in eachmatch(r"function\s+([^\s\(]+\([^\)]*\))", content)
          functions*="```@docs\n"*modname*replace(m.captures[1],r"\:\:[^,]+"=>"")*"\n```\n\n"
        end
        
        #content = replace(content,r"function\s+([^\s\(]+\([^\)]*\))\s+\=\s+"=>s"")
        
        vars = ""
        #for m in eachmatch(r"([^\s]+)\s+\=", content)
        #  vars*="```@docs\n$modname"*m.captures[1]*"\n```\n\n"
        #end
        
        @info "Create $mdfile..."
        open(mdpath,"w+") do f; write(f,"# ["*(hasmodule == nothing ? file : modname[1:end-1])*"](@id $file)\n"*"\n## Variables/Constants\n\n"*vars*"\n## Functions\n\n"*functions); end
        if hasmodule == nothing
          push!(md_source_files, "files/"*mdfile)
        else
          push!(md_modules, "files/"*mdfile)
        end
    end
end

# create docs
@info "Create docs..."
makedocs(
  #root      = root,
  #build     = build,
  #source    = source,
  modules   = [sawhian, Client],
  clean     = true,
  doctest   = true, # :fix
  #linkcheck = true,
  strict    = false,
  checkdocs = :none,
  format    = Documenter.HTML(prettyurls = false),
  sitename  = "AI-Sawhian",
  authors   = "Gilga",
  #html_canonical = "https://github.com/Gilga/AI-Sawhian",
  pages = Any[ # Compat: `Any` for 0.4 compat
      "Home" => "index.md",
      "Manual" => Any[
          "manual/installation.md",
          "manual/start.md",
          "manual/examples.md",
          "manual/references.md",
      ],
      "Modules" => md_modules,
      "Source Files" => md_source_files,
  ],
)

#=
# deploy docs
@info "Deploy docs..."
deploydocs(
  deps   = Deps.pip("mkdocs", "python-markdown-math"), #, "curl"
  repo = "https://github.com/Gilga/AI-Sawhian",
  branch = "gh-pages",
  julia  = "1.1.0",
)
=#

@info "Creating Docs finished."