using Distributed
@everywhere using HTTP, Sockets, Dates


while nprocs() < Sys.CPU_THREADS
    addprocs(1; exeflags="--project")
    @info "adding worker"
end


@info "creating worker pool"
global wp = WorkerPool(workers())

@everywhere begin
    include("solrplant_api.jl")
end
# SERVER FUNCTION
function process_text(;text="")
    @info "GETTING STATS"
    f = remotecall(extract_plants, wp, string(uid), string(tui))
    return fetch(f)
end

function build_server()
    headers = Dict{AbstractString,AbstractString}(
        "Server"            => "Julia/$VERSION",
        "Content-Type"      => "text/html; charset=utf-8",
        "Content-Language"  => "en",
        "Date"              => Dates.format(now(Dates.UTC), Dates.RFC1123Format),
        # "Access-Control-Allow-Origin" => "https://bcbi.brown.edu",
        "Access-Control-Allow-Origin" => "http://localhost:3000",
        "Access-Control-Allow-Methods" => "GET" )

    # route handlers
    h_text = HTTP.Handlers.HandlerFunction( (req) -> begin
            uri = parse(HTTP.URI, req.target)
            query_dict = HTTP.queryparams(uri)

            try
                response = HTTP.Response(200, HTTP.Headers(collect(headers)), body = process_text(text=string(query_dict["text"])))
                return response
            catch
                @show query_dict
                @warn "Incorrect query parameters"
                return HTTP.Response(400, HTTP.Headers(collect(headers)), body = "Incorrect parameters")
            end

        end)

    r = HTTP.Router()

    HTTP.register!(r, "GET", "/text", h_text)

    return HTTP.Servers.Server(r, ratelimit=typemax(Int64)//1)

end


@info "building server"
s = build_server()

@info "running server"
port = 8081
HTTP.Servers.serve(s, "0.0.0.0", port)