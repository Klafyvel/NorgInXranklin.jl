using Norg, AbstractTrees, Xranklin, Logging
"""
    \\norg{rpath}
Try to find a norg file, resolve it and return it.
## Notes
1. the `rpath` is taken relative to the website folder
2. the `rpath` must end with `.norg` and must not start with a `/`
"""
function lx_norg(p::Vector{String})::String
    lc = cur_lc()
    c = Xranklin._lx_check_nargs(:norg, p, 1)
    isempty(c) || return c

    rpath = Xranklin.unixify(strip(p[1]))
    if !endswith(rpath, ".norg")
        @warn """
            \\norg{...}
            The relative path
                <$rpath>
            does not end with '.norg'.
            """
        return Xranklin.failed_lxc("norg", p)
    end

    # try to form the full path to the norg file and check it's there
    fpath = Xranklin.path(:folder) / rpath
    if !isfile(fpath)
        @warn """
            \\norg{...}
            Couldn't find a norg file at path
                <$fpath>
            (resolved from '$rpath').
            """
        return Xranklin.failed_lxc("norg", p)
    end

    # here fpath is the full path to an existing literate script
    return _process_norg_file(lc, rpath, fpath)
end


function is_meta(ast, node)
    if Norg.kind(node) ≠ Norg.K"Verbatim"
        return false
    end
    c1,c2 = first(children(node), 2)
    Norg.textify(ast, c1) == "document" && Norg.textify(ast, c2) == "meta"
end

function parse_meta(ast, metanode)
    d = Dict{Symbol, String}()
    metacontent = Norg.textify(ast, last(children(metanode)))
    for metaline in filter(!isempty, split(metacontent, '\n'))
        k,v = split(metaline, r"\s*:\s*")
        d[Symbol(k)] = v        
    end
    d
end

"""
    _process_norg_file(rpath, fpath)
Helper function to process a norg file located at `rpath` (`fpath`).
We pass `fpath` because it's already been resolved.
"""
function _process_norg_file(
             lc::Xranklin.LocalContext,
             rpath::String,
             fpath::String
         )::String

    pre_log_level = Base.CoreLogging._min_enabled_level[]
    Logging.disable_logging(Logging.Warn)

    # Step 1: read the .norg file
    s = open(fpath) do io
        read(io, String)
    end

    # Step 2: parse the .norg file
    ast = norg(s)

    # Step 3: dirty trick to parse the `@document.meta` tag.
    metanode = first(filter(x->is_meta(ast, x), collect(PreOrderDFS(ast.root))))
    if !isnothing(metanode)
        metadict = parse_meta(ast, metanode)
        for (k,v) in metadict
            setlvar!(k, v)
        end
    end

    # Step 4: generate HTML
    ret = string(Norg.codegen(HTMLTarget(), ast))

    
    # bring back logging level
    Base.CoreLogging._min_enabled_level[] = pre_log_level

    return ret
end

