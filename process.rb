# encoding: utf-8
require 'uri'
require 'json'
require 'set'

dirpath = 'dumps.wikimedia.org/other/mediacounts/daily/2015'
extensions = Hash[ %w[mid ogg ogv wav webm flac oga].map{|ext| [ext, true] } ]
bzfiles = Dir.entries(dirpath).grep(/bz2/)

data = JSON.parse File.read('data.json', encoding: 'utf-8'), symbolize_names: true
done_days = Set.new data.values.map(&:keys).flatten

bzfiles.each do |bzfname|
	day = bzfname[/mediacounts.(\d{4}-\d{2}-\d{2}).v00.tsv.bz2/, 1]
	day = day.to_sym
	if done_days.include? day
		puts "#{bzfname} (skipping)"
		next
	end
	
	pipe = IO.popen(['bzcat', "#{dirpath}/#{bzfname}"], 'rb', encoding: 'utf-8')
	
	while true
		path = pipe.gets("\t")
		if path =~ %r|^/wikipedia/commons/[0-9a-f]/|
			# remove the path prefix: '/wikipedia/commons/h/hh/'
			# remove trailing tab
			filename = URI.unescape path[24..-2]
			
			ext_index = filename.rindex('.')
			if ext_index
				ext = filename[ext_index+1, 999]
				if extensions[ext] || extensions[ext.downcase]
					_ = pipe.gets("\t")
					count = pipe.gets("\t").to_i
					
					filename_sym = filename.to_sym
					data[filename_sym] ||= {}
					data[filename_sym][day] = count
				end
			end
		end
		_ = pipe.gets
		break if pipe.eof?
	end
	
	File.binwrite('data.json', JSON.pretty_generate(data))
	puts bzfname
end
