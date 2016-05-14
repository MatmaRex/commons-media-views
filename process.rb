# encoding: utf-8
require 'uri'
require 'yajl'
require 'set'

GC.disable

dirpath = 'dumps.wikimedia.org/other/mediacounts/daily'
extensions = Hash[ %w[mid ogg ogv wav webm flac oga].map{|ext| [ext, true] } ]
bzfiles = Dir.glob("#{dirpath}/*/*.bz2")

data = File.open('data.json', 'rb') do |f|
	Yajl::Parser.new(symbolize_keys: true).parse f
end
done_days = Set.new data.values.map(&:keys).flatten

bzfiles.each do |bzfname|
	day = bzfname[/mediacounts.(\d{4}-\d{2}-\d{2}).v00.tsv.bz2/, 1]
	day = day.to_sym
	if done_days.include? day
		puts "#{bzfname} (skipping)"
		next
	end
	
	GC.enable; GC.start; GC.disable
	pipe = IO.popen(['bzcat', bzfname], 'rb', encoding: 'utf-8')
	
	n = 0
	while true
		n += 1
		if n % 1_000_000 == 0
			GC.enable; GC.start; GC.disable
		end
		
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
	
	GC.enable # encoding allocates too many objects
	File.open('data.json', 'wb') do |f|
		Yajl::Encoder.encode data, f, pretty: true
	end
	puts bzfname
end
