# Implementation of Smith-Waterman algorithm for Local Alignment of strings
# Nov 21, 2017
# Match = 1; mis-match = -1; gop = {gap opening penalty};
# gep = {gap extension penalty}
# Modified from sw_align.jl to adapt for processing of SRS record strings


# Create scoring matrix and path matrix
function sw_align(seq_a::String, seq_b::String)
    seq_a = "^$seq_a"
    seq_b = "^$seq_b"
    match    = 1.0
    mismatch = -1.0
    gop      = -1.0
    #gep      = -0.5

    col      = length(seq_a)
    row      = length(seq_b)
    matrix   = fill(0.0, (row,col))
    path     = fill("N",(row,col))

    pathvals = ["-","|","M"]
    for i = 2:row
        for j = 2:col
            scores = []
            push!(scores,matrix[i,j-1] + gop)
            push!(scores,matrix[i-1,j] + gop)
            if seq_a[j] == seq_b[i]
                push!(scores, matrix[i-1,j-1] + match)
            else
                push!(scores, matrix[i-1,j-1] + mismatch)
            end
            val,ind = findmax(scores)
            if val < 0
                matrix[i,j] = 0
                #path[i,j] = pathvals[ind]
            else
                matrix[i,j] = val
                path[i,j] = pathvals[ind]
            end

        end
    end
    return matrix, path
end

# Traceback
function traceback(matrix::Array{Float64,2},path::Array{String,2},seq_a::String,seq_b::String)
    seq_a = "^$seq_a"
    seq_b = "^$seq_b"

    irow = size(matrix)[1]
    jcol = size(matrix)[2]

    align1 = []
    align2 = []

    maxval = 0
    ind_x  = 1
    ind_y  = 1
    for i=1:irow
        for j=1:jcol
            if matrix[i,j] > maxval
                maxval = matrix[i,j]
                ind_x  = i
                ind_y  = j
            end
        end
    end
    irow = ind_x
    jcol = ind_y

    check = false
    i = 0
    while !check
        if irow == 1 && jcol == 1
            #push!(align1,seq_a[jcol])
            #push!(align2,seq_b[irow])
            break
        elseif path[irow,jcol] == "M"
            push!(align1,seq_a[jcol])
            push!(align2,seq_b[irow])
            irow -= 1
            jcol -= 1
        elseif path[irow,jcol] == "-"
            push!(align1,seq_a[jcol])
            push!(align2,"-")
            jcol -= 1
            i = i + 1
            #println("\+\+")
        elseif path[irow,jcol] == "|"
            push!(align1,"-")
            push!(align2,seq_b[irow])
            irow -= 1
            #println("\-\-")
        elseif path[irow,jcol] == "N"
            break
        end
    end
    if maxval > 1.0
        if align1[1] == align2[1] && align1[1] == ' '
            deleteat!(align1,1)
            deleteat!(align2,1)
            ind_x = ind_x - 1
            #println("\#")
        end
        if align1[end] == align2[end] && align1[end] == ' '
            pop!(align1)
            pop!(align2)
            #ind_x = ind_x + 1
            #println("\$")
        end
        m = matchall(r"\-", join(align2, ""))
        return align1[end:-1:1], align2[end:-1:1], maxval, ind_x-1, ind_y, seq_b[ind_x-length(align2)+i+1:ind_x]
    else
        m = matchall(r"\-", join(align2, ""))
        return align1[end:-1:1], align2[end:-1:1], maxval, ind_x-1, ind_y, seq_b[ind_x-length(align2)+i+1:ind_x]
    end
end

#seq_a = "Thitmine"
#seq_b = "Thiamine is an amino acid"
#seq_b = "thiamine"

#seq_a = uppercase(seq_a)
#seq_b = uppercase(seq_b)
#matrix, path = sw_align(seq_a,seq_b)
#algn_a, algn_b, scr, indx, indy, mstr = traceback(matrix,path,seq_a,seq_b)
