-- gridauto Lua helper, separated from TeX source to avoid TeX-token expansion
-- while Lua parses a large embedded chunk. Keep this file beside gridauto.sty.
gridauto_sig = gridauto_sig or {}
gridauto_sig.normalize = function(p)
  p = string.gsub(p, string.char(92), "/")
  p = string.gsub(p, "/+", "/")
  return p
end
gridauto_sig.isabs = function(p)
  return string.sub(p, 1, 1) == "/" or (string.len(p) > 1 and string.sub(p, 2, 2) == ":")
end
gridauto_sig.resolve = function(p, base)
  p = gridauto_sig.normalize(p)
  if not gridauto_sig.isabs(p) then p = base .. "/" .. p end
  return gridauto_sig.normalize(p)
end
gridauto_sig.isunder = function(path, root)
  if not root or root == "" then return false end
  root = gridauto_sig.normalize(root)
  return string.sub(path, 1, string.len(root) + 1) == root .. "/" or path == root
end
gridauto_sig.calculate = function()
  local outdir = status.output_directory or ""
  local flsname = tex.jobname .. ".fls"
  if outdir ~= "" then flsname = outdir .. "/" .. flsname end
  local initialbase = os.getenv("PWD") or "."
  local base = initialbase
  local paths = {}
  local lfs_ok, lfs = pcall(require, "lfs")
  local function addpath(p, b)
    if p and p ~= "" then paths[gridauto_sig.resolve(p, b)] = true end
  end
  local fls = io.open(flsname, "r")
  if fls then
    for line in fls:lines() do
      if string.sub(line, 1, 4) == "PWD " then
        base = gridauto_sig.normalize(string.sub(line, 5))
      elseif string.sub(line, 1, 6) == "INPUT " then
        local input_path = string.sub(line, 7)
        if input_path ~= "" then addpath(input_path, base) end
      end
    end
    fls:close()
  end
  addpath(tex.jobname .. ".tex", initialbase)
  local gridauto_file = kpse.find_file("gridauto.sty")
  local gridauto_path = nil
  if gridauto_file then
    gridauto_path = gridauto_sig.resolve(gridauto_file, initialbase)
    paths[gridauto_path] = true
  end
  local scan_ext = {tex=true, sty=true, cls=true, clo=true, def=true, cfg=true,
    bib=true, bbl=true, lua=true, csv=true, tsv=true, txt=true, dat=true,
    tikz=true, pgf=true, md=true, m=true, r=true, xml=true,
    pdf=true, png=true, jpg=true, jpeg=true, eps=true, svg=true, tif=true, tiff=true}
  local walk_ignored = {aux=true, log=true, out=true, toc=true, lof=true, lot=true,
    fls=true, bcf=true, idx=true, ind=true, ilg=true, nav=true, snm=true,
    vrb=true, xdv=true, synctex=true, fdb_latexmk=true, run=true, thm=true}
  local ignored_dirs = { [".git"]=true, [".svn"]=true, ["node_modules"]=true,
    ["__pycache__"]=true, ["build"]=true, ["dist"]=true, ["output"]=true }
  local function extension(p)
    local basefile = p
    local slash_at = string.find(p, "/", 1, true)
    while slash_at do
      basefile = string.sub(p, slash_at + 1)
      slash_at = string.find(p, "/", slash_at + 1, true)
    end
    local ext, dot_at = "", string.find(basefile, ".", 1, true)
    while dot_at do
      ext = string.sub(basefile, dot_at + 1)
      dot_at = string.find(basefile, ".", dot_at + 1, true)
    end
    return string.lower(ext), string.lower(basefile)
  end
  if lfs_ok then
    local scan_roots = {}
    local seen_roots = {}
    local function addroot(r)
      r = gridauto_sig.normalize(r)
      if not seen_roots[r] then
        seen_roots[r] = true
        table.insert(scan_roots, r)
      end
    end
    addroot(initialbase)
    local function exists(path)
      local f = io.open(path, "rb")
      if f then f:close(); return true end
      return false
    end
    local cursor = gridauto_sig.normalize(initialbase)
    for depth = 0, 5 do
      local candidate = cursor .. "/" .. tex.jobname .. ".tex"
      if exists(candidate) then
        addpath(candidate, initialbase)
        addroot(cursor)
        break
      end
      local last = nil
      local slash = string.find(cursor, "/", 1, true)
      while slash do
        last = slash
        slash = string.find(cursor, "/", slash + 1, true)
      end
      if not last then break end
      local parent = string.sub(cursor, 1, last - 1)
      if parent == "" then parent = "/" end
      if parent == cursor then break end
      cursor = parent
    end
    local function walk(dir, depth)
      if depth > 8 then return end
      local ok, iter, state = pcall(lfs.dir, dir)
      if not ok or not iter then return end
      for name in iter, state do
        if name ~= "." and name ~= ".." and not ignored_dirs[name] then
          local full = gridauto_sig.normalize(dir .. "/" .. name)
          local attr_ok, attr = pcall(lfs.attributes, full)
          if attr_ok and attr then
            if attr.mode == "directory" then
              walk(full, depth + 1)
            elseif attr.mode == "file" then
              local ext, basefile = extension(full)
              if scan_ext[ext] and not walk_ignored[ext] and basefile ~= string.lower(tex.jobname .. ".pdf") then
                paths[full] = true
              end
            end
          end
        end
      end
    end
    for _, root in ipairs(scan_roots) do walk(root, 0) end
  end
  local root_names = {"TEXMFROOT", "TEXMFDIST", "TEXMFMAIN"}
  local roots = {}
  for _, root_name in ipairs(root_names) do
    local v = kpse.var_value(root_name)
    if v and v ~= "" then table.insert(roots, gridauto_sig.normalize(v)) end
  end
  local ignored = {aux=true, log=true, out=true, toc=true, lof=true, lot=true,
    fls=true, bcf=true, idx=true, ind=true, ilg=true, nav=true, snm=true,
    vrb=true, xdv=true, synctex=true, fdb_latexmk=true, run=true, thm=true}
  local source_ext = {tex=true, sty=true, cls=true, clo=true, def=true, cfg=true,
    bib=true, bbl=true, lua=true, csv=true, tsv=true, txt=true, dat=true,
    tikz=true, pgf=true, md=true, m=true, r=true, xml=true}
  local ordered = {}
  for p in pairs(paths) do table.insert(ordered, p) end
  table.sort(ordered)
  local h1, h2 = 5381, 52711
  local function hashstr(s)
    for i = 1, string.len(s) do
      local b = string.byte(s, i)
      h1 = math.fmod(h1 * 33 + b, 4294967291)
      h2 = math.fmod(h2 * 65599 + b, 4294967279)
    end
  end
  for _, p in ipairs(ordered) do
    local ext = ""
    local basefile = p
    local slash_at = string.find(p, "/", 1, true)
    while slash_at do
      basefile = string.sub(p, slash_at + 1)
      slash_at = string.find(p, "/", slash_at + 1, true)
    end
    local dot_at = string.find(basefile, ".", 1, true)
    while dot_at do
      ext = string.sub(basefile, dot_at + 1)
      dot_at = string.find(basefile, ".", dot_at + 1, true)
    end
    ext = string.lower(ext)
    basefile = string.lower(basefile)
    local skip = ignored[ext] or basefile == string.lower(tex.jobname .. ".pdf")
    local systemfile = false
    for _, root in ipairs(roots) do
      if gridauto_sig.isunder(p, root) then systemfile = true end
    end
    if not skip and (not systemfile or p == gridauto_path) then
      local f = io.open(p, "rb")
      if f then
        hashstr(p)
        hashstr(string.char(0))
        if source_ext[ext] or p == gridauto_path then
          while true do
            local chunk = f:read(8192)
            if not chunk then break end
            hashstr(chunk)
          end
        elseif lfs_ok then
          local a = lfs.attributes(p)
          if a then
            hashstr(tostring(a.size or 0))
            hashstr(":")
            hashstr(tostring(a.modification or 0))
          else
            hashstr("exists")
          end
        else
          local chunk = f:read(1048576)
          if chunk then hashstr(chunk) end
          local _, size = f:seek("end")
          hashstr(tostring(size or 0))
        end
        f:close()
        hashstr(string.char(1))
      end
    end
  end
  local digits = "0123456789abcdef"
  local function tohex(n)
    local out = ""
    for i = 1, 8 do
      local r = math.fmod(n, 16)
      out = string.sub(digits, r + 1, r + 1) .. out
      n = math.floor(n / 16)
    end
    return out
  end
  return tohex(h1) .. tohex(h2)
end

function gridauto_sig.settexmacro(name)
  tex.sprint(string.char(92) .. "gdef" .. string.char(92) .. name .. "{" .. gridauto_sig.calculate() .. "}")
end
