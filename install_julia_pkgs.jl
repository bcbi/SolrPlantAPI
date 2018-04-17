packages = [ "HTTP",
             "DataFrames", 
             "JSON"]

Pkg.init()
Pkg.update()

for package in packages
    Pkg.add(package)
end

Pkg.resolve()
