local M = {}

function GetPath(str)
	local sep = '/'
	if ya.target_family() == "windows" then
		sep = '\\'
	end
    return str:match("(.*"..sep..")")
end

function Exiftool(...)
	local child = Command("exiftool")
		:args({
			"-q", "-q", "-S", "-Title", "-SortName",
			"-TitleSort", "-TitleSortOrder", "-Artist",
			"-SortArtist", "-ArtistSort", "-PerformerSortOrder",
			"-Album", "-SortAlbum", "-AlbumSort", "-AlbumSortOrder",
			"-AlbumArtist", "-SortAlbumArtist", "-AlbumArtistSort",
			"-AlbumArtistSortOrder", "-Genre", "-TrackNumber",
			"-Year", "-Duration", "-SampleRate", 
			"-AudioSampleRate", "-AudioBitrate", "-AvgBitrate",
			"-Channels", "-AudioChannels", tostring(...),
		})
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:spawn()
	return child
end

function Mediainfo(...)
	local file, cache_dir = ...
	local template = cache_dir.."mediainfo.txt"
	local child = Command("mediainfo")
		:args({
			"--Output=file://"..template, tostring(file)
		})
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
		:spawn()
	return child
end

function M:peek(job)
	local cache = ya.file_cache(job)
	if not cache then
		return
	end

	-- Get cache dir to find the mediainfo template file
	local cache_dir = GetPath(tostring(cache))

	-- Try mediainfo, otherwise use exiftool
	local status, child = pcall(Mediainfo, job.file.url, cache_dir)
	if not status or child == nil then
		status, child = pcall(Exiftool, job.file.url)
		if not status or child == nil then
			local error = ui.Line { ui.Span("Make sure exiftool is installed and in your PATH") }
			-- TODO)) Remove legacy method when v0.4 gets released
			local function display_error_legacy()
				local p = ui.Paragraph(job.area, { error }):wrap(ui.Paragraph.WRAP)
				ya.preview_widgets(job, { p })
			end
			local function display_error()
				local p = ui.Text(error):area(job.area):wrap(ui.Text.WRAP)
				ya.preview_widgets(job, { p })
			end
			if pcall(display_error) then else pcall(display_error_legacy) end
			return
		end
	end

	local limit = job.area.h
	local i, metadata = 0, {}
	repeat
		local next, event = child:read_line()
		if event == 1 then
			return self:fallback_to_builtin()
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			local m_title, m_tag = Prettify(next)
			if m_title ~= "" and m_tag ~= "" then
				local ti = ui.Span(m_title):bold()
				local ta = ui.Span(m_tag)
				table.insert(metadata, ui.Line{ti, ta})
				table.insert(metadata, ui.Line{})
			end
		end
	until i >= job.skip + limit

	-- TODO)) Remove legacy method when v0.4 gets released
	local function display_metadata_legacy()
		local p = ui.Paragraph(job.area, metadata):wrap(ui.Paragraph.WRAP)
		ya.preview_widgets(job, { p })
	end
	local function display_metadata()
		local p = ui.Text(metadata):area(job.area):wrap(ui.Text.WRAP)
		ya.preview_widgets(job, { p })
	end
	if pcall(display_metadata) then else pcall(display_metadata_legacy) end

	local cover_width = job.area.w / 2 - 5
	local cover_height = (job.area.h / 4) + 3

	local bottom_right = ui.Rect {
		x = job.area.right - cover_width,
		y = job.area.bottom - cover_height,
		w = cover_width,
		h = cover_height,
	}

	if self:preload(job) == 1 then
		ya.image_show(cache, bottom_right)
	end
end

function Prettify(metadata)
	local substitutions = {
		Sortname = "Sort Title:",
		SortName = "Sort Title:",
		TitleSort = "Sort Title:",
		TitleSortOrder = "Sort Title:",
		ArtistSort = "Sort Artist:",
		SortArtist = "Sort Artist:",
		Artist = "Artist:",
		ARTIST = "Artist:",
		PerformerSortOrder = "Sort Artist:",
		SortAlbumArtist = "Sort Album Artist:",
		AlbumArtistSortOrder = "Sort Album Artist:",
		AlbumArtistSort = "Sort Album Artist:",
		AlbumSortOrder = "Sort Album:",
		AlbumSort = "Sort Album:",
		SortAlbum = "Sort Album:",
		Album = "Album:",
		ALBUM = "Album:",
		AlbumArtist = "Album Artist:",
		Genre = "Genre:",
		GENRE = "Genre:",
		TrackNumber = "Track Number:",
		Year = "Year:",
		Duration = "Duration:",
		AudioBitrate = "Bitrate:",
		AvgBitrate = "Average Bitrate:",
		AudioSampleRate = "Sample Rate:",
		SampleRate = "Sample Rate:",
		AudioChannels = "Channels:"
	}

	for k, v in pairs(substitutions) do
		metadata = metadata:gsub(tostring(k)..":", v, 1)
	end

	-- Separate the tag title from the tag data
	local t={}
	for str in string.gmatch(metadata , "([^"..":".."]+)") do
		if str ~= "\n" then
			table.insert(t, str)
		else
			table.insert(t, nil)
		end
	end

	-- Add back semicolon to title, rejoin tag data if it happened to contain a semicolon
	local title, tag_data = "", ""
	if t[1] ~= nil then
		title, tag_data = t[1]..":", table.concat(t, ":", 2)
	end
	return title, tag_data

end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		ya.manager_emit("peek", {
			tostring(math.max(0, cx.active.preview.skip + job.units)),
			only_if = tostring(job.file.url),
		})
	end
end

function M:preload(job)
	local cache = ya.file_cache(job)
	if not cache or fs.cha(cache) then
		return 1
	end

	local mediainfo_template = 'General;"\
$if(%Track%,Title: %Track%,)\
$if(%Track/Sort%,Sort Title: %Track/Sort%,)\
$if(%Title/Sort%,Sort Title: %Title/Sort%,)\
$if(%TITLESORT%,Sort Title: %TITLESORT%,)\
$if(%Performer%,Artist: %Performer%,)\
$if(%Performer/Sort%,Sort Artist: %Performer/Sort%,)\
$if(%ARTISTSORT%,Sort Artist: %ARTISTSORT%,)\
$if(%Album%,Album: %Album%,)\
$if(%Album/Sort%,Sort Album: %Album/Sort%)\
$if(%ALBUMSORT%,Sort Album: %ALBUMSORT%)\
$if(%Album/Performer%,Album Artist: %Album/Performer%)\
$if(%Album/Performer/Sort%,Sort Album Artist: %Album/Performer/Sort%)\
$if(%Genre%,Genre: %Genre%)\
$if(%Track/Position%,Track Number: %Track/Position%)\
$if(%Recorded_Date%,Year: %Recorded_Date%)\
$if(%Duration/String%,Duration: %Duration/String%)\
$if(%BitRate/String%,Bitrate: %BitRate/String%)\
"\
Audio;"Sample Rate: %SamplingRate%\
Channels: %Channel(s)%"\
'

	-- Write the mediainfo template file into yazi's cache dir
	local cache_dir = GetPath(tostring(cache))
	fs.write(Url(cache_dir.."mediainfo.txt"), mediainfo_template)

	local output = Command("exiftool")
		:args({ "-b", "-CoverArt", "-Picture", tostring(job.file.url) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not output then
		return 0
	end

	return fs.write(cache, output.stdout) and 1 or 2
end

return M
