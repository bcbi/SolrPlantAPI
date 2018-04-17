# Identification and resolution of Plant taxonomic names
# Feb 19th, 2018
# Author: Vivekanand Sharma, PhD
# Postdoctoral Research Associate
# Center for Biomedical Informatics
# Brown University

using DataFrames
using HTTP
using JSON
# using HttpServer

include("sw_align_srs.jl")
const solr_host  = "http://127.0.0.1:8983/solr"

# Escaping special characters
# replace(str2, r"[+|-|\^|\"|\~|\*|\?|\:|\|/|\!|\&|\|\(|\)]", " OR ")

# Generate query URL from herb name string
function generate_query(string::String)
    string1 = replace(string, r"[\+|\-|\^|\"|\~|\*|\?|\:|\|/|\!|\&|\|\(|\)|\{|\}|\[|\]]", " ")
    string1 = replace(string1, r"[0-9]", "")
    string1 = replace(string1, r"\s{2,}", " ")
    string1 = strip(string1)
    str_arr = Any[]
    query   = ""
    for str in split(string1, " ")
        push!(str_arr, "term:$str\~")
        query = join(str_arr, "\%20OR\%20")
    end
    # url_string = "http://localhost:8983/solr/ubt_plant/select?fl=*,score&q=$query&sort=score%20desc"
    url_string = solr_host*"/ubt_plant/select?fl=*,score&q=$query&sort=score%20desc"
    return url_string
end

# Generate optimal matches for query string
function norm_string(url::String,herb_str::String)
    herb_name = herb_str
    norm_str = ""
    #flag     = 0
    ret_str  = HTTP.get("$url")
    json_str = JSON.parse(String(ret_str.body))
    numFound = json_str["response"]["numFound"]
    if numFound > 0
        herb_str = replace(herb_str, r"\s+cf\.?\s+"i, " ")
        herb_str = replace(herb_str, r"\s+aff\.?\s+"i, " ")
        herb_str = replace(herb_str, r"\s{2,}", " ")
        herb_str = strip(herb_str)
        res_dict = Dict{Float64,String}()
        max_scr = 0
        numFound > 10 ? n = 9 : n = numFound
        for i=1:n
            ubt_id   = json_str["response"]["docs"][i]["ubt_id"][1]
            name     = json_str["response"]["docs"][i]["term"][1]
            solr_scr = round(json_str["response"]["docs"][i]["score"][1],2)
            typ      = json_str["response"]["docs"][i]["type"][1]
            seq_b = uppercase(herb_str)
            seq_a = uppercase(name)
            # Old version:
            #seq_a = uppercase(herb_str)
            #seq_b = uppercase(name)
            if ismatch(r"([A-Z][a-z\-]+\s[a-z]{0,3}\.?\s*[a-z\-]+)\.?.*", name)
                matrix, path = sw_align(seq_a,seq_b)
                algn_a, algn_b, scr, indx, indy, mstr = traceback(matrix,path,seq_a,seq_b)
                name_pd  = name
                name_len = length(name)  #length(split(herb_str, " ")[1])
                algn_len = length(algn_a)

                coverage = round((algn_len/name_len)*100, 2)
                if coverage == 100.00
                    mapping = check_match(seq_a, seq_b, algn_a, indx, mstr)
                    #scr > max_scr ? max_scr = scr : max_scr = max_scr
                    if mapping == "match"
                        if scr > max_scr
                            max_scr = scr
                            res_dict[scr] = "$herb_name\$$ubt_id\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$typ"
                            #println("$herb_name\$$name\$$name_pd\$$solr_scr\$$scr\$$name_len\$$coverage\$$mapping")
                        end
                    end
                else
                    name_pd  = match(r"([A-Z][a-z\-]+\s[a-z]{0,3}\.?\s*[a-z\-]+)\.?.*", name).captures[1]
                    name_pd  = String(name_pd)

                    seq_a    = uppercase(name_pd)
                    matrix, path = sw_align(seq_a,seq_b)
                    algn_a, algn_b, scr, indx, indy, mstr = traceback(matrix,path,seq_a,seq_b)
                    name_len = length(name_pd)
                    algn_len = length(algn_a)
                    coverage = round((algn_len/name_len)*100, 2)
                    if coverage > 80.00
                        mapping = check_match(seq_a, seq_b, algn_a, indx, mstr)
                        if mapping == "match"
                            if scr > max_scr
                                max_scr = scr
                                res_dict[scr] = "$herb_name\$$ubt_id\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$typ"
                                #println("$herb_name\$$name\$$name_pd\$$solr_scr\$$scr\$$name_len\$$coverage\$$mapping")
                            end
                        end
                    end
                end
            else
                matrix, path = sw_align(seq_a,seq_b)
                algn_a, algn_b, scr, indx, indy, mstr = traceback(matrix,path,seq_a,seq_b)
                name_len = length(name)  #length(split(herb_str, " ")[1])
                algn_len = length(algn_a)

                coverage = round((algn_len/name_len)*100, 2)
                if coverage > 80.00
                    mapping = check_match(seq_a, seq_b, algn_a, indx, mstr)
                    if mapping == "match"
                        if scr > max_scr
                            max_scr = scr
                            res_dict[scr] = "$herb_name\$$ubt_id\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$typ"
                            #println("$herb_name\$$name\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$mapping")
                        end
                    end
                end
            end
        end

        return get(res_dict, max_scr, "$herb_name\$NA\$NA\$NA\$NA\$NA\$NA\$NA")
    else
        return "$herb_name\$NA\$NA\$NA\$NA\$NA\$NA\$NA"
    end
end

# Check for match or no-match
function check_match(seq_a, seq_b, algn_a, indx, mstr)
    cs1 = indx-length(mstr)+1
    ce1 = collect(rsearch(seq_b, " ", indx))
    if length(ce1) > 0
        if seq_b[cs1] == seq_a[1] && seq_b[ce1[end]+1] == split(seq_a, " ")[end][1]
            return "match"
        else
            return "no-match"
        end
    else
        if seq_b[cs1] == seq_a[1] && seq_b[1] == split(seq_a, " ")[end][1]
            return "match"
        else
            return "no-match"
        end
    end
end

# Retrieve accepted name
function accepted_name(ubt_id::String)
    # url_string = "http://localhost:8983/solr/ubt_plant/select?q=ubt_id:$ubt_id%20AND%20type:sciname"
    url_string = solr_host*"/ubt_plant/select?q=ubt_id:$ubt_id%20AND%20type:sciname"
    ret_str  = HTTP.get("$url_string")
    json_str = JSON.parse(String(ret_str.body))
    name     = json_str["response"]["docs"][1]["term"][1]
    return name
end


function resolve_name(name_subm::String)
    name_subm  = chomp(name_subm)
    herb       = strip(String(name_subm))
    url        = generate_query(herb)
    norm       = norm_string(url,herb)
    name_match = split(norm, "\$")[3]
    ubt_id     = String(split(norm, "\$")[2])
    match_typ  = ucfirst(split(norm, "\$")[end])

    accept_name = "NA"

    if ubt_id != "NA" 
        println("ubt_id: ", ubt_id)
        accept_name = accepted_name(ubt_id) 
    end

    println("Accepted name ", accept_name)
    if match_typ == "Sciname" 
        match_typ = "Scientific Name"
    end
    return "\{\"NameSubmitted\"\:\"$name_subm\"\,\"NameMatched\"\:\"$name_match\"\,\"TaxonomicStatus\"\:\"$match_typ\"\,\"uBiotaID\"\:$ubt_id\,\"AcceptedName\"\:\"$accept_name\"\}"
end


function run_server()

    query_dict = Dict()

    HTTP.listen() do request::HTTP.Request
       
        println("******************")
        @show request
        println("******************")

        uri = parse(HTTP.URI, request.target)
        query_dict = HTTP.queryparams(uri)

        headers = Dict{AbstractString,AbstractString}(
            "Server"            => "Julia/$VERSION",
            "Content-Type"      => "text/html; charset=utf-8",
            "Content-Language"  => "en",
            "Date"              => Dates.format(now(Dates.UTC), Dates.RFC1123Format),
            "Access-Control-Allow-Origin" => "*" )

        return HTTP.Response(200, HTTP.Headers(collect(headers)), body = String(resolve_name(query_dict["plantname"])))
    end


end

run_server()