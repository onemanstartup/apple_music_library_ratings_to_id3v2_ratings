# Conversion of Apple Music App library ratings and play counts to id3v2 compatible format
# readable by other music players.
require 'taglib' # https://taglib.org/api/index.html
require 'plist'

library_path = '/Users/j/Music/NewLibrary.xml'

# Parse Library.xml
library = Plist.parse_xml(library_path)
tracks = library['Tracks']
tracks_count = tracks.count

# Schema of tracks array
# ["12999", {"Track ID"=>12999, "Name"=>"So Young", "Artist"=>"Veronica", "Album"=>"Phil Spector: Back to Mono 1958-1969", "Kind"=>"MPEG audio file", "Size"=>2505175, "Total Time"=>156342, "Track Number"=>14, "Year"=>1991, "Date Modified"=>#<DateTime: 2013-02-10T07:48:18+00:00 ((2456334j,28098s,0n),+0s,2299161j)>, "Date Added"=>#<DateTime: 2008-01-30T16:20:18+00:00 ((2454496j,58818s,0n),+0s,2299161j)>, "Bit Rate"=>126, "Sample Rate"=>44100, "Play Count"=>7, "Play Date"=>3490043537, "Play Date UTC"=>#<DateTime: 2014-08-04T20:32:17+00:00 ((2456874j,73937s,0n),+0s,2299161j)>, "Normalization"=>2333, "Artwork Count"=>1, "Persistent ID"=>"3A1328FA3020270D", "Track Type"=>"File", "Location"=>"file:///Volumes/Mac/Music/Veronica/Phil%20Spector_%20Back%20to%20Mono%201958-1969/14%20So%20Young.mp3", "File Folder Count"=>5, "Library Folder Count"=>1}]
tracks.each_with_index do |(n, track), i|
  location = track['Location'].sub('file:///', '/')

  TagLib::MPEG::File.open(CGI.unescape(location)) do |file|
    if file.open?
      tag = file.id3v2_tag

      # What is proccessed right now
      # 01 / 10000 - title
      puts  "#{(i+1).to_s.ljust(tracks_count.to_s.size)} / #{tracks_count} - #{tag.title}"
     
      # Is Rating is set?
      txx_frame = tag.frame_list('TXXX')
      field_list = txx_frame.select { |e| e.field_list.first == 'FMPS_Rating' }&.first&.field_list
      next unless field_list
     
      # Convert fpms rating (0.0 to 1.0) to 100 based rating
      rating = (field_list.last.to_f * 100).to_i
     
      # Some players take rating from TXXX field RATING
      rating_frame = TagLib::ID3v2::UserTextIdentificationFrame.new
      rating_frame.description = 'RATING'
      rating_frame.text = rating.to_s
      tag.add_frame(rating_frame)
    
      # Most players are using new popularimeter frame
      # https://id3.org/id3v2.3.0#Popularimeter
      popm_frame = TagLib::ID3v2::PopularimeterFrame.new
      popm_frame.counter = track["Play Count"] if track["Play Count"]
      # It is 1 to 255 based. I know right.
      popm_frame.rating = 255 / (100 / rating )
      tag.add_frame(popm_frame)
     
      file.save
    else
      # Sometimes Apple Music have absent files or maybe TagLib can't open file.
      puts "No such file - #{location}"
    end
  end
end
