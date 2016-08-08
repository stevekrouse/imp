module Datasets

using Data

function read_chinook(filename, types; comments=false)
  rows, _ = readdlm(open(filename), '\t', header=true, quotes=false, comments=comments)
  n = length(types)
  columns = tuple([Vector{types[c]}() for c in 1:n]...)
  for r in 1:size(rows)[1]
    for c in 1:n
      if types[c] == String
        push!(columns[c], string(rows[r, c]))
      elseif isa(rows[r, c], SubString)
        @show r c rows[r, c]
      else
        push!(columns[c], rows[r, c])
      end
    end
  end
  Relation(columns)
end

album = read_chinook("data/Album.csv", [Int64, String, Int64])
artist = read_chinook("data/Artist.csv", [Int64, String])
track = read_chinook("data/Track.csv", [Int64, String, Int64, Int64, Int64, String, Int64, Int64, Float64])
playlist_track = read_chinook("data/PlaylistTrack.csv", [Int64, Int64])
playlist = read_chinook("data/Playlist.csv", [Int64, String])

export album, artist, track, playlist_track, playlist

using DataFrames

function read_job()
  schema = readdlm(open("data/job_schema.csv"), ',', header=false, quotes=true, comments=false)
  table_column_names = Dict()
  table_column_types = Dict()
  for column in 1:size(schema)[1]
    table_name, ix, column_name, column_type = schema[column, 1:4]
    push!(get!(table_column_names, table_name, []), column_name)
    push!(get!(table_column_types, table_name, []), (column_type == "integer" ? Int64 : String))
  end
  relations = Dict()
  for (table_name, column_names) in table_column_names
    if isfile("../job/$(table_name).csv")
      column_types = table_column_types[table_name]
      @show table_name column_names column_types
      frame = readtable(open("../imdb/$(table_name).csv"), header=false, eltypes=column_types)
      n = length(frame[1])
      ids = copy(frame[1].data)
      for (ix, (column_name, column_type)) in enumerate(zip(column_names, column_types))
        @show table_name ix column_name column_type
        data_array = frame[ix]
        if ix == 1
          relations[table_name, column_name] = Relation((ids,))
        else
          column_ids = Int64[id for (ix, id) in enumerate(ids) if !(data_array.na[ix])]
          local column
          if isa(data_array, DataArray{Int64})
            let data::Vector{Int64} = data_array.data
              column = Int64[d for (ix, d) in enumerate(data) if !(data_array.na[ix])]
            end
          elseif isa(data_array, DataArray{String})
            let data::Vector{String} = data_array.data
              column = String[d for (ix, d) in enumerate(data_array.data) if !(data_array.na[ix])]
            end
          end
          relations[table_name, column_name] = Relation((column_ids, column))
        end
      end
    end
  end
  relations
end

using JLD

# job = @time read_job()
# @time save("../job/imp.jld", "job", job)

job = @time load("../job/imp.jld", "job")

gc()

export job

end
