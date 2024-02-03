local M = {}

function M:peek()
	local cache = ya.file_cache(self)
	if not cache then
		return
	end

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
			"-Channels", "-AudioChannels", tostring(self.file.url),
		})
		:stdout(Command.PIPED)
		:stderr(Command.NULL)
	:spawn()

	local limit = self.area.h
	local i, metadata = 0, ""
	repeat
		local next, event = child:read_line()
		if event == 1 then
			return self:fallback_to_builtin()
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > self.skip then
			metadata = metadata .. next
		end
	until i >= self.skip + limit

	metadata = prettify_metadata(metadata)

	-- Show the cover art only if the preview pane is not hidden
	local cover_width = 0
	local cover_height = 0
	if self.area.right ~= self.area.x then
		cover_width = self.area.right / 6
		cover_height = self.area.bottom / 3
	end

	local bottom_right = ui.Rect {
		x = self.area.right - cover_width,
		y = self.area.bottom - cover_height,
		w = cover_width,
		h = cover_height,
	}

	if self:preload() == 1 then
		ya.preview_widgets(self, { ui.Paragraph.parse(self.area, metadata) })
		ya.image_show(cache, bottom_right)
	end
end

function prettify_metadata(metadata)
	local my_os = ya.target_family()
	local eb = "\27[1m" -- Enable bold
	local db = "\27[0m" -- Disable bold
	-- The Windows terminal doesn't seem to support ANSI escape codes? Untested
	if my_os == "windows" then 
		eb = ""
		db = ""
	end

	local substitutions = {
		Title = ""..eb.."Title:"..db,
		SortName = "\n"..eb.."Sort Title:"..db,
		TitleSort = "\n"..eb.."Sort Title:"..db,
		TitleSortOrder = "\n"..eb.."Sort Title:"..db,
		Artist = "\n"..eb.."Artist:"..db,
		ARTIST = "\n"..eb.."Artist:"..db,
		SortArtist = "\n"..eb.."Sort Artist:"..db,
		ArtistSort = "\n"..eb.."Sort Artist:"..db,
		PerformerSortOrder = "\n"..eb.."Sort Artist:"..db,
		Album = "\n"..eb.."Album:"..db,
		ALBUM = "\n"..eb.."Album:"..db,
		SortAlbum = "\n"..eb.."Sort Album:"..db,
		AlbumSort = "\n"..eb.."Sort Album:"..db,
		AlbumSortOrder = "\n"..eb.."Sort Album:"..db,
		AlbumArtist = "\n"..eb.."Album Artist:"..db,
		SortAlbumArtist = "\n"..eb.."Sort Album Artist:"..db,
		AlbumArtistSort = "\n"..eb.."Sort Album Artist:"..db,
		AlbumArtistSortOrder = "\n"..eb.."Sort Album Artist:"..db,
		Genre = "\n"..eb.."Genre:"..db,
		GENRE = "\n"..eb.."Genre:"..db,
		TrackNumber = "\n"..eb.."Track Number:"..db,
		Year = "\n"..eb.."Year:"..db,
		Duration = "\n"..eb.."Duration:"..db,
		AudioBitrate = "\n"..eb.."Bitrate:"..db,
		AvgBitrate = "\n"..eb.."Average Bitrate:"..db,
	}

	for k, v in pairs(substitutions) do
		metadata = metadata:gsub(tostring(k) .. ":", v, 1)
	end
	-- Exceptions
	metadata,sc = metadata:gsub("AudioSample", "\n"..eb.."Sample")
	if sc ~= 0 then
		metadata = metadata:gsub("SampleRate:", ""..eb.."Sample Rate:"..db)
	else
		metadata = metadata:gsub("SampleRate:", "\n"..eb.."Sample Rate:"..db)
	end
	metadata,sc = metadata:gsub("AudioChannels:", "\n"..eb.."Channels:"..db)
	if sc == 0 then
		metadata = metadata:gsub("Channels:", "\n"..eb.."Channels:"..db)
	end
	return metadata
end

function M:seek(units)
	local h = cx.active.current.hovered
	if h and h.url == self.file.url then
		ya.manager_emit("peek", {
			tostring(math.max(0, cx.active.preview.skip + units)),
			only_if = tostring(self.file.url),
		})
	end
end

function M:preload()
	local cache = ya.file_cache(self)
	if not cache or fs.cha(cache) then
		return 1
	end

	local output = Command("exiftool")
		:args({ "-b", "-CoverArt", "-Picture", tostring(self.file.url) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not output then
		return 0
	end

	return fs.write(cache, output.stdout) and 1 or 2
end

return M
