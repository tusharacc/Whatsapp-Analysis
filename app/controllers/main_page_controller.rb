
require 'securerandom'

class MainPageController < ApplicationController

	def index
		cookies[:user_name] = SecureRandom.hex
        session[:file_name] = SecureRandom.hex

        logger.debug "The number cookie generated is #{cookies[:user_name]}"
        logger.debug "The number session generated is #{session[:file_name]}"
    end

    def process_file
		fl_name = SecureRandom.hex
		cookies[:name] = {value: fl_name, expires: 1.year.from_now}
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
	      logger.debug "The number of items #{line}"
	      if line.strip.length > 0
	        line_split = line.scan(/(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)/)
	        
	        if line_split.count == 0
	          regular_chat_hash = {date:date_of_sent_text, time: time_of_sent_text, name: name_of_sender, sent_text: line}
	          @regular_chat.push(regular_chat_hash)
	        else
	          case line_split[0].count
	          
	          when 3
	            line_split_get_name_text = line_split[0][2].scan(/([A-Za-z\s]+):\s(.+)/)
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
	    logger.debug "The number of lines in specific is #{@specific_lines.count}"
	    logger.debug "The number of lines in specific is #{@regular_chat.count}"
	    logger.debug "The cookie data is #{cookies[:name]}"
	    logger.debug "The session data is #{session[:file_name]}"
	end

	def update_message_list
    	logger.debug "The number of lines in specific is updr #{cookies[:name]}"

    	respond_to do |format|
      		format.js 
      		format.html
    	end
  	end
end
