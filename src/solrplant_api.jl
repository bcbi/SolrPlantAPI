# Identification and resolution of Plant taxonomic names
# Nov 8th, 2018
# Author: Vivekanand Sharma, PhD
# Postdoctoral Research Associate
# Center for Biomedical Informatics
# Brown University
# Pre-processing involves text tokenization and noun phrase parsing.

    
using DataFrames
using HTTP
using JSON
using PyCall
#using HttpServer

@pyimport nltk as ntk
@pyimport textblob
@pyimport textblob.np_extractors as npx
#@pyimport textblob.taggers as ptag

include("sw_align_srs.jl")

# Escaping special characters
# replace(str2, r"[+|-|\^|\"|\~|\*|\?|\:|\|/|\!|\&|\|\(|\)]", " OR ")

const solr_host = "http://127.0.0.1:8983/solr"
#Sentence tokenization
function sentTokenization(txt, ntk)
    sent_arr = ntk.sent_tokenize(txt)
    for i in 1:length(sent_arr)
        if i < length(sent_arr)
            if occursin(r"[Nn]o\.\s[a-z0-9]", sent_arr[i] * " " * sent_arr[i+1]) || occursin(r"[A-Za-z]\.\s[a-z0-9]", sent_arr[i] * " " * sent_arr[i+1])
                sent_arr[i] = sent_arr[i] * " " * sent_arr[i+1] #* "\."
                deleteat!(sent_arr, i+1)
            end
        end
    end
    if sent_arr[length(sent_arr)] == "" || isempty(sent_arr[length(sent_arr)])
        deleteat!(sent_arr, length(sent_arr))
    end
    return sent_arr
end


# Generate query URL from herb name string
function generate_query(string::String)
    string1 = replace(string, r"[\+|\-|\^|\"|\~|\*|\?|\:|\|/|\!|\&|\|\(|\)|\{|\}|\[|\]]" => " ")
    string1 = replace(string1, r"[0-9]" => "")
    string1 = replace(string1, r"\s{2,}" => " ")
    string1 = strip(string1)
    str_arr = Any[]
    query   = ""
    for str in split(string1, " ")
        push!(str_arr, "term:$str~")
        query = join(str_arr, "%20OR%20")
    end
    url_string = solr_host * "/ubt_plant/select?fl=*,score&q=$query&sort=score%20desc"
    #url_string = "http://bcbi.brown.edu/solr/solr/ubt_plant/select?fl=*,score&q=$query&sort=score%20desc"
    return url_string
end

# Generate recursive query URL from herb name string
function generate_sub_query(string::String, not_arr)
    string1 = replace(string, r"[\+|\-|\^|\"|\~|\*|\?|\:|\|/|\!|\&|\|\(|\)|\{|\}|\[|\]\,]" => " ")
    string1 = replace(string1, r"[0-9]" => "")
    string1 = replace(string1, r"\s{2,}" => " ")
    string1 = strip(string1)
    str_arr = Any[]
    yes_query   = ""
    not_query = ""
    for str in split(string1, " ")
        push!(str_arr, "term:$str~")
        yes_query = join(str_arr, "%20OR%20")
    end
    if length(not_arr) > 0
        name_arr = String[]
        for name in not_arr
            #println("$name \=\>")
            for str in split(name, " ")
                push!(name_arr, "term:$str")
                not_query = join(name_arr, "%20OR%20")
            end
        end
        query = "($yes_query)%20NOT%20($not_query)"
        #println(query)
    else
        query = yes_query
    end

    url_string = solr_host * "/ubt_plant/select?fl=*,score&q=$query&sort=score%20desc&rows=10"
    @info "***Solr URL"
    @show url_string
    #url_string = "http://bcbi.brown.edu/solr/solr/ubt_plant/select?fl=*,score&q=$query&sort=score%20desc"
    return url_string
end

# Generate optimal matches for query string
function norm_string(url::String,herb_str::String)
    herb_name = herb_str
    norm_str = ""
    #flag     = 0
    ret_str  = HTTP.request("GET","$url";)
    json_str = JSON.parse(String(ret_str.body))
    @info "***JSON response"
    @show json_str
    numFound = json_str["response"]["numFound"]
    #println(json_str)
    if numFound > 0
        herb_str = replace(herb_str, r"\s+cf\.?\s+"i => " ")
        herb_str = replace(herb_str, r"\s+aff\.?\s+"i => " ")
        herb_str = replace(herb_str, r"\s{2,}" => " ")
        herb_str = strip(herb_str)
        res_dict = Dict{Float64,String}()
        max_scr = 0
        numFound > 10 ? n = 10 : n = numFound

        for i=1:n
            ubt_id   = json_str["response"]["docs"][i]["ubt_id"][1]
            name     = json_str["response"]["docs"][i]["term"][1]
            solr_scr = round(json_str["response"]["docs"][i]["score"][1], digits = 2)
            typ      = json_str["response"]["docs"][i]["type"][1]
            seq_b = uppercase(herb_str)
            seq_a = uppercase(name)
            # Old version:
            #seq_a = uppercase(herb_str)
            #seq_b = uppercase(name)
            if occursin(r"([A-Z][a-z\-]+\s[a-z]{0,3}\.?\s*[a-z\-]+)\.?.*", name)
                matrix, path = sw_align(seq_a,seq_b)
                algn_a, algn_b, scr, indx, indy, mstr = traceback(matrix,path,seq_a,seq_b)
                name_pd  = name
                name_len = length(name)  #length(split(herb_str, " ")[1])
                algn_len = length(algn_a)

                coverage = round((algn_len/name_len)*100, digits = 2)
                if coverage == 100.00
                    mapping = check_match(seq_a, seq_b, algn_a, indx, mstr)
                    #scr > max_scr ? max_scr = scr : max_scr = max_scr
                    if mapping == "match"
                        if scr > max_scr
                            max_scr = scr
                            filter!(x -> x!="-", algn_b)
                            res_dict[scr] = "$(ucfirst(lowercase(join(algn_b))))\$$ubt_id\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$typ"
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
                    coverage = round((algn_len/name_len)*100, digits = 2)
                    if coverage > 80.00
                        mapping = check_match(seq_a, seq_b, algn_a, indx, mstr)
                        if mapping == "match"
                            if scr > max_scr
                                max_scr = scr
                                filter!(x -> x!="-", algn_b)
                                res_dict[scr] = "$(ucfirst(lowercase(join(algn_b))))\$$ubt_id\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$typ"
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

                coverage = round((algn_len/name_len)*100, digits = 2)
                if coverage > 80.00
                    mapping = check_match(seq_a, seq_b, algn_a, indx, mstr)
                    if mapping == "match"
                        if scr > max_scr
                            max_scr = scr
                            filter!(x -> x!="-", algn_b)
                            res_dict[scr] = "$(ucfirst(lowercase(join(algn_b))))\$$ubt_id\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$typ"
                            #println("$herb_name\$$name\$$name\$$solr_scr\$$scr\$$name_len\$$coverage\$$mapping")
                        end
                    end
                end
            end
        end
        return get(res_dict, max_scr, "$herb_name\$NA\$NA\$NA\$NA\$NA\$NA\$NA"), numFound
    else
        return "$herb_name\$NA\$NA\$NA\$NA\$NA\$NA\$NA", numFound
    end
end

# Check for match or no-match
function check_match(seq_a, seq_b, algn_a, indx, mstr)
    cs1 = indx-length(mstr)+1
    ce1 = collect(rsearch(seq_b, " ", indx))
    seq_b = "$seq_b "
    string(seq_b[indx+1]) != " " ? sp = search(seq_b, " ", indx)[end] : sp = indx
    cs1 == 1 ? cs1 = 2 : cs1 = cs1
    if string(seq_b[cs1-1]) == " " || occursin(Regex("^$(seq_b[cs1-1])"), seq_b)
        cs1 == 2 ? cs1 = 1 : cs1 = cs1
        if length(ce1) > 0
            if seq_b[cs1] == seq_a[1] && seq_b[ce1[end]+1] == split(seq_a, " ")[end][1] && abs(sp-(indx+1)) <= 2 # || occursin(Regex("$(seq_b[indx])\$"), seq_b))
                if occursin(r"\s", seq_a)
                    return "match"
                else
                    if seq_a[end] == seq_b[indx]
                        return "match"
                    else
                        return "no-match"
                    end
                end
            else
                return "no-match"
            end
        else
            if seq_b[cs1] == seq_a[1] && seq_b[1] == split(seq_a, " ")[end][1] && seq_a[end] == seq_b[indx]
                return "match"
            else
                return "no-match"
            end
        end
    else
        return "no-match"
    end
end

# Retrieve accepted name
function accepted_name(ubt_id::String)
    url_string = solr_host * "/ubt_plant/select?q=ubt_id:$ubt_id%20AND%20type:sciname"
    #url_string = "http://bcbi.brown.edu/solr/solr/ubt_plant/select?q=ubt_id:$ubt_id%20AND%20type:sciname"
    ret_str  = HTTP.request("GET","$url_string";)
    json_str = JSON.parse(String(ret_str.body))
    #ubt_id   = json_str["response"]["docs"][i]["ubt_id"][1]
    name     = json_str["response"]["docs"][1]["term"][1]
    return name
end

# Resolve plant species names
function resolve_name(herb::String)
    ret_arr  = String[]
    name_arr = String[]
    n = trunc(Int, length(split(herb, " "))/2)
    n == 0 ? n = 1 : nothing
    for i in 1:n
        herb = replace(lowercase(herb), r"(\s[A-Za-z0-9]{2}\s|\s[A-Za-z0-9]{2}$|^[A-Za-z0-9]{2}\s)" => " ")
        herb = replace(herb, r"\s+" => " ")
        println("Herb:" , herb)
        url  = generate_sub_query(herb, name_arr)
        println("URL: ", url)
        res_str, num_found = norm_string(url,herb)
        println("Resolved name: ", res_str)
        num_found == 0 ? break : nothing
        if length(split(split(res_str, "\$")[1], " ")) >= 2
            split(res_str, "\$")[2] != "NA" ? name_subm = split(res_str, "\$")[1] : name_subm  = "No Matches"
            ubt_id     = String(split(res_str, "\$")[2])
            name_match = split(res_str, "\$")[3]
            match_typ  = ucfirst(split(res_str, "\$")[end])
            ubt_id != "NA" ? accept_name = accepted_name(ubt_id) : accept_name = "NA"
            match_typ == "Sciname" ? match_typ = "Scientific Name" : match_typ = match_typ
            push!(name_arr, split(res_str, "\$")[3])
            push!(ret_arr, """{"NameSubmitted":"$name_subm","NameMatched":"$name_match","TaxonomicStatus":"$match_typ","uBiotaID":"$ubt_id","AcceptedName":"$accept_name"}""")
            split(res_str, "\$")[2] == "NA" ? break : nothing
        else
            push!(ret_arr, """{"NameSubmitted":"No Matches","NameMatched":"NA","TaxonomicStatus":"NA","uBiotaID":"NA","AcceptedName":"NA"}""")
        end
    end
    ret_arr = unique(ret_arr)
    length(ret_arr) != 1 ? ret_arr = ret_arr[1:end-1] : nothing
    return "[$(join(ret_arr, ","))]"
end

# Take input as text for resolving names
function extract_plants(text, extractor)
    ret_arr = Any[]
    txt = replace(text, r"\n+" => " ")
    txt = replace(txt, r"\*\s" => "")
    txt = replace(txt, r"\%" => "")
    txt = strip(txt)
    println("text after stripping: ", txt)
    sent_arr = sentTokenization(txt, ntk)
    println("text after tokenization: ", sent_arr)

    for sent in sent_arr
        nphrs = textblob.TextBlob(sent, np_extractor=extractor)

        for phrs in nphrs["noun_phrases"]
            println("Noun phrase: ", phrs)
            try
                norm_str = resolve_name(phrs)
                println("Resolved name: ", norm_str)
                json_str = JSON.parse(String(norm_str))
                for i in 1:length(json_str)
                    if json_str[i]["NameSubmitted"] != "No Matches" && json_str[i]["NameSubmitted"] != "Unknown"
                        name_subm  = json_str[i]["NameSubmitted"]
                        name_match = json_str[i]["NameMatched"]
                        match_typ  = json_str[i]["TaxonomicStatus"]
                        ubt_id     = json_str[i]["uBiotaID"]
                        accept_name = json_str[i]["AcceptedName"]
                        #println("$(json_str[i]["NameSubmitted"])\$$(json_str[i]["NameMatched"])\$$(json_str[i]["AcceptedName"])")
                        push!(ret_arr, """{"NameSubmitted":"$name_subm","NameMatched":"$name_match","TaxonomicStatus":"$match_typ","uBiotaID":$ubt_id,"AcceptedName":"$accept_name"}""")
                        println("Ret Array: ", ret_arr)
                    end
                end
            catch err
                println(err)
                continue
            end
        end
    end
    return "[$(join(ret_arr, ","))]"
end





# function run_server()

#     query_dict = Dict()

#     HTTP.listen() do request::HTTP.Request
       
#         println("******************")
#         @show request
#         println("******************")

#         uri = parse(HTTP.URI, request.target)
#         query_dict = HTTP.queryparams(uri)

#         headers = Dict{AbstractString,AbstractString}(
#             "Server"            => "Julia/$VERSION",
#             "Content-Type"      => "text/html; charset=utf-8",
#             "Content-Language"  => "en",
#             "Date"              => Dates.format(now(Dates.UTC), Dates.RFC1123Format),
#             "Access-Control-Allow-Origin" => "*" )

#         return HTTP.Response(200, HTTP.Headers(collect(headers)), body = String(extract_plants(query_dict["text"])))
#     end


# end

# run_server()

#############
### TESTS ###
#############
#herb = "Strychnos nux-vomica"
herb = "This sentence contains Raulfia serpentina, Mangifera indica and Arabidoopsis thaliana of plantae, glycine and fabaceae family in it."
#herb = "This sentence has no analysis plantae ginkgo biloba." # names in it."
#herb = "Arabidopsis"
#herb = "This study focussed on the effect of increasing nitrogen (N) supply on root uptake and root-to-shoot translocation of zinc (Zn) as well as retranslocation of foliar-applied Zn in durum wheat (Triticum durum)."
#herb = "plantae"
#herb = "Apical buds of Norway spruce (Picea abies) trees at high and low elevation were heated during 2006 and 2007."
#herb_arr = ["Strychnos nux-vomica",
#    "This sentence contains Raulfia serpentina, Mangifera indica and Arabidoopsis thaliana of plantae and fabaceae family in it.",
#    "This sentence has no plantae names in it.",
#    "Arabidopsis",
#    "This sentence contains Raulfia serpentina, Mangifera indica and Arabidoopsis thaliana of plantae and fabaceae family in it.",
#    "This sentence contains Raulfia serpentina, Mangifera indica and Arabidoopsis thaliana of plantae and fabaceae family in it."]
#herb = "Arabidoopsis thaliane Pigment stripes associated arabidoopsis thaliane cycle with veins (venation) is a common flower colour pattern."
#herb = "Apical hydraulic conductivity (k) was estimated from anatomical data."
#herb = "Here we quantified intraspecific variation and covariation of leaf mass per area (LMA) and wood density (WD) in monospecific forests of the widespread tree species Nothofagus pumilio to determine its magnitude and whether it is related to environmental conditions and ontogeny."
#herb = "arabidopsis thaliana"
#herb = "Arabidopsis thaliana"
#herb = "This sentence has no plant names in it."
#startTime = time()
#for herb in herb_arr
#    println(resolve_name(herb))
#    println("\=\=\=\=\=")
#end
#endTime = time()
#println("########################")
#println("Time taken: $(round(endTime-startTime, 2)) sec.")
#println("########################")

# extractor = npx.ConllExtractor()
# text = herb
# pt_spec = extract_plants(text, extractor)
# println(pt_spec)