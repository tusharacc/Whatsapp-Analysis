
require 'securerandom'
require 'json'

class MainPageController < ApplicationController
	#before_filter :common_content, :only => [:process_file, :update_message_list, :get_media_omitted]
	

	def index
		cookies[:user_name] = SecureRandom.hex
        session[:file_name] = SecureRandom.hex

        logger.debug "The number cookie generated is #{cookies[:user_name]}"
        logger.debug "The number session generated is #{session[:file_name]}"
    end

    def process_file
		fl_name = SecureRandom.hex
		#cookies[:name] = {value: fl_name}
		tempfl = params[:file]
		@lines = params[:file].read.to_s

		@lines = File.read(tempfl.tempfile)
	    logger.error "Bad file name #{@lines}"
	    @errored_lines = []
	    @specific_lines=[]
	    @regular_chat = []
	    @member_name = []
	    date_of_sent_text = ""
	    time_of_sent_text = ""
	    name_of_sender = ""
	    line_cnt = 0
	    @earliest_date = ''
	    @last_date = ''
	    @lines.each_line do |line|  
	      
	      	if line.strip.length > 0
	        	line_split = line.scan(/(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)/)
	        
	        	if line_split.count == 0
	          		regular_chat_hash = {date:date_of_sent_text, time: time_of_sent_text, name: name_of_sender, sent_text: line}
	          		@regular_chat.push(regular_chat_hash)
	        	else
	          		case line_split[0].count
	          
	          		when 3
	            		line_split_get_name_text = line_split[0][2].scan(/(.+?):(.+)/)
	            		if line_split_get_name_text.count == 0
	              			@specific_lines.push(line)
	            		else
	              			date_of_sent_text = line_split[0][0]
	              			time_of_sent_text = line_split[0][1]
	              			name_of_sender = line_split_get_name_text[0][0]
	              			if @member_name.index(name_of_sender).nil?
	                			@member_name.push(name_of_sender)
	              			end
	              			sent_text = line_split_get_name_text[0][1]
	              			if sent_text == "<Media omitted>"
	                			@specific_lines.push(line)
	              			else
	                			regular_chat_hash = {date:date_of_sent_text, time: time_of_sent_text, name: name_of_sender, sent_text: sent_text}
	                			@regular_chat.push(regular_chat_hash)
	              			end
	            		end
	          		else
	            		@errored_lines.push(line)
	          		end
	        	end
	      	end
	      	if line_cnt == 0
	        	@earliest_date = date_of_sent_text
	      	else
	        	@last_date = date_of_sent_text
	      	end
	      	line_cnt += 1
	    end

	    File.open(Rails.root.join('public', 'uploads', session[:file_name]+"_regular.json"), 'wb') do |file|
    		file.write(JSON.pretty_generate(@regular_chat))
  		end

  		File.open(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), 'wb') do |file|
    		@specific_lines.each {|line| file.write(line)}	
  		end

	    logger.debug "The number of lines in specific is #{@specific_lines.count}"
	    logger.debug "The number of lines in specific is #{@regular_chat.count}"
	    logger.debug "The cookie data is #{cookies[:name]}"
	    logger.debug "The session data is #{session[:file_name]}"
	end

	def update_message_list
    	get_count_per_member
		logger.debug "The message summary is #{@messages}"
		get_average_per_day
    	get_media_omitted
    	get_members_added
    	respond_to do |format|
      		format.js 
      		format.html
    	end
  	end

  	#private

  	def get_count_per_member
  		@messages = []
    	#logger.debug "the file name is #{{}}"
    	file = File.read(Rails.root.join('public', 'uploads', session[:file_name]+'_regular.json'))
    	text_hash = JSON.parse(file)

		text_hash.each do |hsh|
			name = hsh['name']
			not_found = true
			a = 0
			@messages.each do |rec|
			
				if rec['name'] == name
					not_found = false
					#puts rec
					@messages[a]['count'] = rec['count'] + 1
				end
					a += 1
			end
			if not_found
				@messages.push({'name'=>name,'count'=>1})
			end
		end

  	end

  	def get_average_per_day
  		dt = ''
  		@messages_per_day = []
  		day_map = {"1"=>"Monday","2"=>"Tuesday","3"=>"Wednesday","4"=>"Thursday","5"=>"Friday","6"=>"Saturday","7"=>"Sunday"}
  		file = File.read(Rails.root.join('public', 'uploads', session[:file_name]+'_regular.json'))
    	text_hash = JSON.parse(file)
    	latest_date = Date.strptime(text_hash[0]['date'],'%m/%d/%Y')
    	text_hash.each do |hsh|
    		logger.debug "the hsh is #{hsh}"
			dt = hsh['date']
			day_num = Date.strptime(dt, '%m/%d/%Y').cwday 
			not_found = true
			a = 0
			@messages_per_day.each do |rec|
				if rec['day'] == day_map[day_num.to_s]
					not_found = false
					@messages_per_day[a]['count'] = rec['count'] + 1
				end
				a += 1
			end
			if not_found
				@messages_per_day.push({'day'=>day_map[day_num.to_s],'count'=>1})
			end
			
    	end
    	day_count = {"1"=>0,"2"=>0,"3"=>0,"4"=>0,"5"=>0,"6"=>0,"7"=>0}
    	(Date.strptime(dt,'%m/%d/%Y')..latest_date).each do |orig_date|
    		day_count.each do |k,v|
				if k == orig_date.cwday.to_s
					day_count[k] = v + 1
				end
    		end
    	end

    	logger.debug "the number of messages per day is #{day_count}"
    	logger.debug "the number of messages per day is #{@messages_per_day}"
    	
    	@messages_per_day.each_with_index do |val,index| 
    		@messages_per_day[index]['count'] = @messages_per_day[index]['count']/day_count[@messages_per_day[index]['day']]  
    	end

  	end

  	def get_media_omitted
  		count = 0
  		file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
  		#logger.debug "File Name is #{Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt")}"
  		file.each do |line|
  			line_split = line.scan(/(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)/)
		    if line_split[0][-1] == "<Media omitted>"
				#logger.debug 'I am in, what you want to do'
				count += 1
    		end

  		end
		file.close

  		# count = 0
  		# if @specific_lines != nil
	  	# 	@specific_lines.each do |line|
	  	# 		line_split = line.scan(/(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)/)
	  	# 		if line_split[0][-1] == "<Media omitted>"
				# 	count += 1
				# end
	  	# 	end
	  	# else
	  	# 	logger.debug "@specific_lines is nil"
	  	# end

  		@media_added = count
  		#logger.debug "The number of time media was added #{@media_added}"
  	end

  	def get_members_added
  		count = 0
  		file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
  		#logger.debug "File Name is #{Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt")}"
  		file.each do |line|
  			line_split = line.scan(/(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)/)
  			#if line_split.count != 0 
  				if line_split[0].count == 3
  					#logger.debug "The line we are looking at #{line_split[0][-1]}"
  					#logger.debug "The index we are looking at #{line_split[0][-1].index("added")}"
  					if line_split[0][-1].index("added") != nil
						count += 1
					end
				end
			#end
  		end
  		@members_added = count
  	end
end
