require "erb"
require "open-uri"
require "nokogiri"
require "pp"
require "json"

class Epw

	COLLOCATION = 3

	WEBLIO_URL = "http://ejje.weblio.jp/content"
	GOIMG_URL  = "https://www.google.com/search?hl=jp&q=%word%&btnG=Google+Search&tbs=0&safe=off&tbm=isch"

	#WEBLIOM_URL = "http://ejje.weblio.jp/english-thesaurus/content"
	WEBLIOM_URL = "https://www.ldoceonline.com/jp/dictionary"
	PRONUNCIATION_XPATH = "//b[@class='KejjeHt']"
	MEANS_XPATH = "//td[@class='content-explanation ej']"
	#MEANSE_XPATH = "//p[@class='wdntTCLE']"
	MEANSE_XPATH = "//span[@class='DEF']"
	WTYPE_XPATH = "//div[@class='KnenjSub']"
	EXAMPLE_XPATH = "//div[@class='qotC']"
	WMV_XPATH = "//div[@id='ePsdDl']/a/@href"
	IMG_XPATH = "//div[@class='rg_meta notranslate']"
	#IMG_XPATH = "//div[@jscontroller='Q7Rsec']"
	#IMG_XPATH = "//body"
	USER_AGENT = 'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.63 Safari/537.36'

	def output_html
		get_words
		#sort_words あったものから消せばいい
		get_known_list
		get_known_collo_list

#		base_html = get_html_template
		words_htmls = get_words_htmls
		csv = words_htmls.join("\n")

		#	output csv
	end

	private
	def get_words
		@org_form_list = []
		@all_doc = File.open("epw.txt", "r"){|f|f.read}
		#@all_doc.downcase!
		@all_doc = @all_doc.gsub(/\n+/,".")
		@all_doc = @all_doc.gsub(/\.+/,".")
		@all_doc = @all_doc.gsub(/[-\n]+/," ")
		@all_doc = @all_doc.gsub(/[^a-zA-Z\s\(\)\[\]\{\}"'\.,]+/,"")

		reg = Regexp.new('(\([a-zA-Z\.,\s]*?\)|\[[a-zA-Z\.,\s]*?\]|\{[a-zA-Z\.,\s]*?\}|"[a-zA-Z\.,\s]*?"|\'[a-zA-Z\.,\s]*?\')')
		while reg.match(@all_doc) do
			@all_doc = @all_doc.sub(/#{reg}(.*?\.)/){"#{$2}#{$1.gsub(/[^a-zA-Z\s]/,"")}\."}
		end
		@all_doc = @all_doc.gsub(/\s+(\.|,)/,'\1')
		@all_doc = @all_doc.gsub(/(\.|,)\s+/,'\1')
		@all_doc = @all_doc.gsub(/\s+/," ")
		@all_doc = @all_doc.gsub(/(?:^|.|,)[A-Z][a-z]+/){|s| s.downcase}
		@all_doc = @all_doc.gsub(/[^a-zA-Z\s\.,]+/,"")
		#if @all_doc.match(/(\s|\.|,)+the(\s|\.|,)+/,"")
		#@all_doc = @all_doc.gsub(/(\s\.,)+([A-Z])[a-z]+/,"#{$2.downcase}")
		@all_doc = @all_doc.gsub(/(\s|\.|,)+an\s/,'\1')
		@all_doc = @all_doc.gsub(/\san(\.|,|\s)+/,'\1')
		@all_doc = @all_doc.gsub(/(\s|\.|,)+a\s/,'\1')
		@all_doc = @all_doc.gsub(/\sa(\.|,|\s)+/,'\1')
		@all_doc = @all_doc.gsub(/(\s|\.|,)+the\s/,'\1')
		@all_doc = @all_doc.gsub(/\sthe(\.|,|\s)+/,'\1')
		puts @all_doc
		@all_doc_master = @all_doc
		@all_sents = @all_doc.split(/\.|,/)
		@all_sents.each_with_index {|sents,i|
			puts "#{i} #{sents}"
		}
		#all_docから単語リスト作成
	end

	def get_known_collo_list
		@known_collo_word = []
		File.open("known_collo_words.csv", "r") do |file|
			file.each_line do |labmen|
				@known_collo_word.push(labmen.chomp)
			end
		end
		puts @known_collo_word.join("\n")
	end


	def get_known_list
		@known_word = []
		File.open("known_list.txt", "r") do |file|
			file.each_line do |labmen|
				@known_word.push(labmen.chomp)
			end
		end
	end
	#def get_words
	#@words = File.open("epw.words", "r") {|f|f.read}.split("\n")
	#if @words.size == 0
	#puts "no word in epw.words"
	#exit
	#end
	#end


	def known_collo_chk(w)
		w.split("\s").each {|word|
			if @known_collo_word.include?(word) == false then
				return 0
			end
		}
		puts "#{w}は連語リストに含まれる単語で構成されるためスキップします"
		return 1

	end

	def sort_words
		@words.sort!
	end

#	def get_html_template
#		File.open("epw.html.template", "r") {|f|f.read}
#	end

	def get_words_htmls
		File.open("epw_test.csv", "w") do |f|
			""
		end
		htmls = []
		collomax = COLLOCATION

		sent_cnt = 0
		@all_sents_now = @all_sents.clone
		while sent_cnt < @all_sents_now.length do
			#@word = @all_sents[sent_cnt].split(/\s+/)

			for collon in 0..collomax - 1
				collo = collomax - collon
				@all_sents_now[sent_cnt] = @all_sents[sent_cnt]
				#3,2,1で回す予定
				#ここは実質1センテンスのループ 最小値1 0は回らず終了
				#word_cnt = 0
				#while word_cnt < @all_sents_now[sent_cnt].split(/\s+/).length - collo  do
				while @all_sents_now[sent_cnt].split(/\s+/).length > collo - 1  do
					puts "sent_cnt = #{sent_cnt}"
					puts "collo = #{collo}"
					@words = @all_sents_now[sent_cnt].split(/\s+/)	
					w = ""
					for i in 0..collo-1 do	
						w << @words[i] + " "
					end
					w = w.gsub(/ $/,"")
					known_collo_chk(w)
					#if @known_word.include?(w) then
					#				puts "#{w}は既出なのでスキップします"
					#				@all_sents_now[sent_cnt] = @all_sents_now[sent_cnt].gsub(/(^|\s)#{w}(\s+|$)/,"")
					#				@all_sents_now[sent_cnt].gsub!(/(^\s)|(\s$)/,"")
					#				next
					#end
					known_collo_flg = known_collo_chk(w)
					known_flg = 0
					@known_word.each {|kword|
						#kword AB CDE FG  w CDE 
						if kword =~ /(^#{w}(\s|$))|(\s#{w}(\s|$))/ then
							puts "#{w}は#{kword}にて既出なのでスキップします"
							known_flg = 1
							break
						end
					}	
					if known_flg == 1 || known_collo_flg == 1 then
						@all_sents_now[sent_cnt] = @all_sents_now[sent_cnt].gsub(/^#{w}(\s+|$)/,"")
						@all_sents_now[sent_cnt].gsub!(/(^\s)|(\s$)/,"")
						next
					end


					begin
						htmls << append_word(w)
						@known_word.push(w)
						File.open("epw_test.csv", "a") do |f|
							f.puts htmls[htmls.length-1] + "\n"
						end
						del_cnt = 0
						while del_cnt < @all_sents.length do
							#puts "success del"
							#puts w
							#puts "del"
							@all_sents_now[del_cnt] = @all_sents_now[del_cnt].gsub(/(^|\s)#{w}(\s|$)/," ")
							@all_sents_now[del_cnt].gsub!(/(^\s)|(\s$)/,"")
							#@all_sents[del_cnt] = @all_sents[del_cnt].gsub(/#{w}(\s|$)/,"")
							#puts @all_sents_now[del_cnt]
							#puts @all_sents[del_cnt]
							del_cnt += 1
						end
					rescue NONREGError =>e
						#print(e.message,"\n")
						#変化系はここで削除　本当に良いか要検討
						#del_cnt = 0
						#while del_cnt < @all_sents.length do
						#				@all_sents[del_cnt] = @all_sents[del_cnt].gsub(/#{w}\s+/,"")
						#				@all_sents_now[del_cnt] = @all_sents_now[del_cnt].gsub(/#{w}\s+/,"")
						#				del_cnt += 1
						#end

						puts "IN NONREGErorr @all_sents_now[#{sent_cnt}] = #{@all_sents_now[sent_cnt]}"

						#@words[word_cnt] = e.message
						#@words.uniq
						#原形、変化系をwhileつかって削除が必要?否、redo時に原形は消える

						#これまで原形redo行ったものリスト(配列)化して重複回避が必要
						#if @org_form_list.include?(e.message) then
						#if @known_word.include?(e.message) then
						#				puts "#{w}の原型は#{e.message}で@known_wordsに存在しているため"
						#				puts "#{w}も@known_wordsに追加します"
						#				del_cnt = 0
						#				while del_cnt < @all_sents.length do
						#								#@all_sents_now[del_cnt] = @all_sents_now[del_cnt].gsub(/(^|\s)#{w}(\s|$)/," ")
						#								#@all_sents[del_cnt] = @all_sents[del_cnt].gsub(/(^|\s)#{w}(\s|$)/," ")
						#								@all_sents_now[del_cnt] = @all_sents_now[del_cnt].gsub(/(^|\s)#{w}(\s|$)/," ")
						#								@all_sents_now[del_cnt].gsub!(/(^\s)|(\s$)/,"")
						#								del_cnt += 1
						#				end
						#else
						puts "#{w}の原型は#{e.message}なので、@all_sents_nowの#{w}を"
						puts "#{e.message}に置き換えて調べ直します。"
						@all_sents_now[sent_cnt].gsub!(/^#{w}/,"#{e.message}")
						#@org_form_list.push("#{e.message}")
						redo
						#end

					rescue => error
						print(w,"\t: ",error,"\n")
						#del_cnt = 0
						#while del_cnt < @all_sents.length do
						#@all_sents[sent_cnt] = @all_sents[sent_cnt].gsub(/\#{w}\s+/,"")
						#@all_sents_now[sent_cnt] = @all_sents_now[sent_cnt].gsub(/\#{w}\s+/,"")
						#@all_sents[del_cnt] = @all_sents[del_cnt].gsub(/#{w}\s+/,"")
						@all_sents_now[sent_cnt] = @all_sents_now[sent_cnt].gsub(/^#{@words[0]}(\s+|$)/,"")
						#del_cnt += 1
						#end
					end 
					#word_cnt += 1
				end

			end
			sent_cnt += 1


		end

		htmls
	end

	def append_word(word)
		puts word
		sleep(1.0)
		page = URI.parse("#{WEBLIO_URL}/#{word.gsub(/ /,"+")}").read
		@document = Nokogiri::HTML(page)
		means = get_means(word)
		puts "means = " + means
		get_pron_file(word)
		image = get_image_file(word)
		wtype = get_wtype(word)
		example = get_example(word)
		pronunciation = get_pronunciation(word)
		meanse = get_meanse(word)
		word_template = "<%=word%>\t<%=wtype%>\t<%=meanse%>\t<%=example%>\t<%=means%>\t"

		if File.exist?("pronunciation/#{word}.mp3") then
			word_template << "[sound:#{word}.mp3]\t"
		else
			word_template << "\t"
		end
		word_template << "<%=pronunciation%>\t<%=image%>"

		erb = ERB.new(word_template)
		erb.result(binding)
	end

	def get_wtype(word)
		begin
			@document.xpath(WTYPE_XPATH).first.text.gsub("/", "") 
		rescue
			print(word," word type not found.\n")
			""	    
		end
	end

	def get_example(word)
		begin
			retstr = @document.xpath(EXAMPLE_XPATH).first.text.gsub(/例文帳に追加/, " : ")
			retstr = retstr.gsub(/-[^\-]*$/,"")
		rescue
			print(word," example not found.\n")
			""	    
		end
	end

	def get_pronunciation(word)
		begin
			@document.xpath(PRONUNCIATION_XPATH).first.text.gsub("/", "")
		rescue
			print(word," pronunciation not found.\n")
			""	    
		end
	end

	def get_means(word)
		begin
			retstr = @document.xpath(MEANS_XPATH).first.text.gsub("/", "")
		rescue
			#print(word," synonym not found.\n")
			""
			raise MEANSError
		end
		if retstr =~ /(の三人称単数現在|の複数形|の過去形|の過去分詞|の現在分詞)/ then
			#retstr = retstr.gsub(/([a-zA-Z\s]+)の.*$/,'\1')
			retstr =~ /([a-zA-Z\s]+)の#{$1}$/
			retstr = $1
			print(retstr,"\n")
			raise NONREGError,retstr
		end
		puts "means = " + retstr
		return retstr
	end

	def get_meanse(word)
		retstr = ""
		count = 1
		begin
			page = URI.parse("#{WEBLIOM_URL}/#{word}").read
			document = Nokogiri::HTML(page)
			print(document.xpath(MEANSE_XPATH).length,"\n")
			document.xpath(MEANSE_XPATH).each do |node|
				retstr << node.text + "<BR>"
				count += 1
				if count > 3 then
					break
				end
			end
		rescue
			print(word," english means not found.\n")
			""	    
		end
		retstr.gsub(/<BR>$/,"")
	end

	def get_weblio_url(word)
		print(word)
		"#{WEBLIO_URL}/#{word}"
	end

	def get_image_file(word)
		begin
			#temp_path = "#{GOIMG_URL}".gsub(/%word%/,"#{word}+illustration")
			page_img = URI.open("#{GOIMG_URL.gsub(/%word%/,"#{word.gsub(/ /,"+")}")}","User-Agent" =>"#{USER_AGENT}")
			print("#{GOIMG_URL}".gsub(/%word%/,"#{word.gsub(/ /,"+")}"),"\n")
			imgument = Nokogiri::HTML.parse(page_img,nil,"UTF-8")
			count = 1
			#			print(imgument.xpath(IMG_XPATH).length,"\n")
			retstr = ""
			imgument.xpath(IMG_XPATH).each do |img_url|
				img_url = JSON.parse(img_url.text)
				img_url = img_url['ou'].to_s
				puts img_url
				if img_url =~ /\.(jpg|png|gif).*$/ then
					pref = $1
					open("#{img_url}") do |source|
						open("img/#{word.gsub(/\s/,"_")}#{count}.#{pref}", "w+b") do |o|
							o.print source.read
						end
					end
					retstr << "<img src=\"#{word.gsub(/ /,"_")}#{count}.#{pref}\" />"
					count += 1
					if count > 3 then
						break
					end
				end

			end
		rescue => error
			print(error,"\n")
		end
		retstr
	end


	def get_pron_file(word)
		begin
			puts "in get_pron_file(#{word})"
			pron_url = @document.xpath(WMV_XPATH).to_s
			base = WMV_URL1
			puts "open(#{pron_url})"
			open("#{pron_url}") do |source|
				open("pronunciation/#{word}.mp3", "w+b") do |o|
					o.print source.read
				end
			end
		rescue
		end
	end

	def output(html)
		File.open("epw_test.csv", "w") do |f|
			f.puts html
		end
	end
	class WTYPEError < StandardError
	end
	class MEANSError < StandardError
	end
	class EXAMPLEError < StandardError
	end
	class PRONError < StandardError
	end
	class AUDIOError < StandardError
	end
	class NONREGError < StandardError
	end
end

epw = Epw.new
epw.output_html
