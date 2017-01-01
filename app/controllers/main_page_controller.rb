
require 'securerandom'
require 'json'

class MainPageController < ApplicationController
  
  REGEX_ORIGINAL_LINE = Regexp.new('(\d+\/\d+\/\d+),\s(\d+:\d+:\d+\s\w+):\s(.+$)') #used to split original line
  REGEX_GET_TIME = Regexp.new('(.+):.+\s(\S+)')
  REGEX_GET_AM_PM = Regexp.new('(.+):.+\s(\S+)')
  DATE_FORMAT = '%d/%m/%y'
  #(\d+\/\d+\/\d+),\s(\d+:\d+:\d+\s\w+):\s(.+$)
  #REGEX_ORIGINAL_LINE = Regexp.new('\d+\/\d+\/\d+),\s(\d+:\d+:\d+\s\w+):\s(.+$)') #used to split original line
  REGEX_SPLIT_TEXT = Regexp.new('(.+?):(.+)') #used to split text portion of REGEX_ORIGINAL_LINE
  IMAGE_TEXT = "<image omitted>"
  AUDIO_TEST = "<audio omitted>"


  def get_weekdays (startDate, endDate,day)
    count = 0
    #logger.debug "The date is #{startDate} & #{endDate} & #{startDate.class} & #{endDate.class} #{day.class} & #{count}"
    (Date.strptime(startDate,'%Y-%m-%d')..Date.strptime(endDate,'%Y-%m-%d')).each do |dt|
      if dt.cwday.to_s == day 
        count += 1
      end
    end
    #logger.debug "The date is #{startDate} & #{endDate} & #{startDate.class} & #{endDate.class} #{day} & #{count}"
    return count

  end

  def index
    cookies[:user_name] = SecureRandom.hex
    session[:file_name] = SecureRandom.hex

    #logger.debug "The number cookie generated is #{cookies[:user_name]}"
    #logger.debug "The number session generated is #{session[:file_name]}"
  end

  def process_file


    #OLD_REGEX_ORIGINAL_LINE = Regexp.new('(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)')
    #OLD_IMAGE_TEXT = '<Media omitted>'

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
    @lines.each_line do |line|

      if line.strip.length > 0
        line_split = line.scan(REGEX_ORIGINAL_LINE)

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
              if sent_text == IMAGE_TEXT or sent_text == AUDIO_TEST
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
      #
      #CHANGE THE SLICE LINE FOR DATES
      #
      if line_cnt == 0
        if date_of_sent_text == ''
          @earliest_date = line.slice(0,8)
          #logger.debug "I am after count per month 1 #{@earliest_date}"
        else
          @earliest_date = date_of_sent_text
          #logger.debug "I am after count per month #{@earliest_date}"
        end
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

    #logger.debug "The number of lines in specific is #{@specific_lines.count}"
    #logger.debug "The number of lines in specific is #{@regular_chat.count}"
    #logger.debug "The cookie data is #{cookies[:name]}"
    #logger.debug "The session data is #{session[:file_name]}"
  end

  def update_message_list



    people = params['people']
    @member = people
    from_dt = params['from-date']
    to_dt = params['to-date']
    #logger.debug "The from date is #{from_dt}"
    #logger.debug "The to date is #{to_dt}"

    file = File.read(Rails.root.join('public', 'uploads', session[:file_name]+'_regular.json'))

    if people == "All"
      get_count_per_member(file,from_dt,to_dt, people)
    end
    get_summary(file,from_dt,to_dt, people)
    #logger.debug "I am after count per member"
    get_average_per_day(file,from_dt,to_dt, people)
    #logger.debug "I am after count per day"
    get_average_per_time_slot(file,from_dt,to_dt, people)
    #logger.debug "I am after count per time"
    get_per_month(file,from_dt,to_dt, people)
    #logger.debug "I am after count per month"

    #file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
    get_media_omitted(from_dt,to_dt,people)
    get_members_added(from_dt,to_dt,people)
    get_number_of_times_group_left(from_dt,to_dt,people)
    #logger.debug "The number of time group left #{@group_left}"
    get_number_of_times_group_name_changed(from_dt,to_dt,people)
    get_number_of_times_group_pic_changed(from_dt,to_dt,people)
    
    respond_to do |format|
      format.js
      format.html
    end
  end

  #private
  def get_average_per_time_slot(file,from_dt,to_dt,*name)



    @time_slot = [{'slot'=>'12:01-4:00 AM','count'=>0},{'slot'=>'4:01-8:00 AM','count'=>0},{'slot'=>'8:01-12:00 PM','count'=>0},{'slot'=>'12:01-4:00 PM','count'=>0},{'slot'=>'4:01-8:00 PM','count'=>0},{'slot'=>'8:01-12:00 AM','count'=>0}]


    text_hash = JSON.parse(file)
    text_hash.each do |hsh|
      time = hsh['time']
      read_from_dt = Date.strptime(hsh['date'],DATE_FORMAT).to_s
      hour = time.scan(/(.+):.+\s(\S+)/)[0][0].to_f
      am_pm = time.scan(/(.+):.+\s(\S+)/)[0][1]

      if from_dt <= read_from_dt and to_dt >= read_from_dt

        case name[0]
        when 'All'
          populate_time_slot(am_pm,hour)
        else
          #logger.debug "The name that came #{name[0]} & #{hsh['name']}"
          if name[0] == hsh['name']
            populate_time_slot(am_pm,hour)
          end
        end
      end
    end
    #file.close
  end

  def populate_time_slot (am_pm,hour)
    if am_pm == 'PM'
      hour = hour + 12.0
    end
    index = hour/4.0
    if index > 0 and index <=1.0
      @time_slot[0]['count'] += 1
    elsif index > 1.0 and index <=2.0
      @time_slot[1]['count'] += 1
    elsif index > 2.0 and index <=3.0
      @time_slot[2]['count'] += 1
    elsif index > 3.0 and index <=4.0
      @time_slot[3]['count'] += 1
    elsif index > 4.0 and index <=5.0
      @time_slot[4]['count'] += 1
    elsif index > 5.0 and index <=6.0
      @time_slot[5]['count'] += 1
    end

  end

  def get_per_month(file,from_dt,to_dt,*name)



    @messages_per_month = [{'month'=>'January','count'=>0},{'month'=>'February','count'=>0},{'month'=>'March','count'=>0},{'month'=>'April','count'=>0},{'month'=>'May','count'=>0},{'month'=>'June','count'=>0},{'month'=>'July','count'=>0},{'month'=>'August','count'=>0},{'month'=>'September','count'=>0},{'month'=>'October','count'=>0},{'month'=>'November','count'=>0},{'month'=>'December','count'=>0}]

    text_hash = JSON.parse(file)

    latest_date = Date.strptime(text_hash[0]['date'],DATE_FORMAT)
    oldest_date = Date.strptime(text_hash[-1]['date'],DATE_FORMAT)
    #logger.debug "The oldest date  #{latest_date}"
    #logger.debug "The oldest date  #{oldest_date}"
    text_hash.each do |text|
      read_from_dt = Date.strptime(text['date'],DATE_FORMAT).to_s
      #logger.debug "The date is #{text['date']}"
      #logger.debug "The date is #{read_from_dt}"
      if from_dt <= read_from_dt and to_dt >= read_from_dt
        message_month = Date.strptime(text['date'], DATE_FORMAT).mon
        case name[0]
        when 'All'
          populate_month_slot(message_month)
        else
          if name[0] == text['name']
            populate_month_slot(message_month)
          end
        end
        #logger.debug "The oldest date  #{message_month}"

      end
    end
    #logger.debug "The number of messages per month  #{@messages_per_month}"
    #file.close
  end

  def populate_month_slot(message_month)
    case message_month
    when 1
      @messages_per_month[0]['count'] += 1
    when 2
      @messages_per_month[1]['count'] += 1
    when 3
      @messages_per_month[2]['count'] += 1
    when 4
      @messages_per_month[3]['count'] += 1
    when 5
      @messages_per_month[4]['count'] += 1
    when 6
      @messages_per_month[5]['count'] += 1
    when 7
      @messages_per_month[6]['count'] += 1
    when 8
      @messages_per_month[7]['count'] += 1
    when 9
      @messages_per_month[8]['count'] += 1
    when 10
      @messages_per_month[9]['count'] += 1
    when 11
      @messages_per_month[10]['count'] += 1
    when 12
      @messages_per_month[11]['count'] += 1
    else
      logger.debug "the process failed in month section #{date}"
    end
  end

  def get_count_per_member(file,from_dt,to_dt,*name)
    @messages = []
    #logger.debug "the file name is #{{}}"

    text_hash = JSON.parse(file)

    text_hash.each do |hsh|
      read_from_dt = Date.strptime(hsh['date'],DATE_FORMAT).to_s

      if from_dt <= read_from_dt and to_dt >= read_from_dt
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
    #file.close
  end

  def get_average_per_day(file,from_dt,to_dt,*name)
    dt = ''
    #@messages_per_day =[{"Day":"Monday","Count":30},{"Day":"Tuesday","Count":50}]
    @messages_per_day = []
    day_map = {"1"=>"Monday","2"=>"Tuesday","3"=>"Wednesday","4"=>"Thursday","5"=>"Friday","6"=>"Saturday","7"=>"Sunday"}

    text_hash = JSON.parse(file)
    latest_date = Date.strptime(text_hash[0]['date'],DATE_FORMAT)
    text_hash.each do |hsh|
      #logger.debug "the hsh is #{hsh}"
      read_from_dt = Date.strptime(hsh['date'],DATE_FORMAT).to_s

      if from_dt <= read_from_dt and to_dt >= read_from_dt
        day_num = Date.strptime(hsh['date'], DATE_FORMAT).cwday
        not_found = true
        a = 0
        @messages_per_day.each do |rec|
          if rec['day'] == day_map[day_num.to_s]
            not_found = false
            case name[0]
            when 'All'
              @messages_per_day[a]['count'] = rec['count'] + 1
            else
              if name[0] == hsh['name']
                @messages_per_day[a]['count'] = rec['count'] + 1
              end
            end
            #@messages_per_day[a]['count'] = rec['count'] + 1
          end
          a += 1
        end
        if not_found
          case name[0]
          when 'All'
            @messages_per_day.push({'day'=>day_map[day_num.to_s],'count'=>1})
          else
            if name[0] == hsh['name']
              @messages_per_day.push({'day'=>day_map[day_num.to_s],'count'=>1})
            end
          end
        end
      end
    end

    temp_arr = @messages_per_day.map do |arr|
      day_of_week = day_map.key(arr['day'])
      number_of_days = get_weekdays(from_dt,to_dt,day_of_week)
      logger.debug "The date is in kdn #{number_of_days} #{day_of_week}"
      arr['count'] = arr['count']/number_of_days
    end
    #file.close

    logger.debug "the average of messages per day is #{temp_arr}"
    #logger.debug "the number of messages per day is #{@messages_per_day}"

    #@messages_per_day.each_with_index do |val,index|
    # @messages_per_day[index]['count'] = @messages_per_day[index]['count']/day_count[@messages_per_day[index]['day']]
    #end

  end

  def get_media_omitted (from_dt,to_dt,*name)



    count = 0
    file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
    #logger.debug "File Name is #{Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt")}"
    file.each do |line|
      line_split = line.scan(REGEX_ORIGINAL_LINE)
      if line_split[0][-1] == IMAGE_TEXT or line_split[0][-1] == AUDIO_TEST
        #logger.debug 'I am in, what you want to do'
        case name[0]
        when 'All'
          count += 1
        else
          if name[0] == line_split[0][-1].scan(/(.+):\s.+/)[0][0] and dt >= from_dt and dt <= to_dt
            count += 1
          end
        end
      end

    end

    file.close
    @media_added = count
    #logger.debug "The number of time media was added #{@media_added}"
  end

  def get_members_added (from_dt,to_dt,*name)
    count = 0
    file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
    #logger.debug "File Name is #{Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt")}"
    file.each do |line|
      line_split = line.scan(REGEX_ORIGINAL_LINE)
      #if line_split.count != 0
      if line_split[0].count == 3
        #logger.debug "The line we are looking at #{line_split[0][-1]}"
        #logger.debug "The index we are looking at #{line_split[0][-1].index("added")}"
        dt = Date.strptime(line_split[0][0],DATE_FORMAT).to_s
        if line_split[0][-1].index("added") != nil
          case name[0]
          when 'All'
            if dt >= from_dt and dt <= to_dt
              count += 1
            end
          else
            if name[0] == line_split[0][-1].scan(/(.+)\added\s.+/) and dt >= from_dt and dt <= to_dt
              count += 1
            end
          end
        end
      end
      #end
    end
    file.close
    @members_added = count
  end

  def get_number_of_times_group_pic_changed (from_dt,to_dt,*name)
    count = 0
    file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
    #logger.debug "File Name is #{file.class}"
    file.each do |line|
      #logger.debug "The line we are looking at #{line}"
      #line_split = line.scan(/(\d+\/\d+\/\d+),\s(\d+:\d+\s\w+)\s-\s(.*$)/)
      #if line_split.count != 0
      line_split = line.scan(REGEX_ORIGINAL_LINE)
      if line_split[0].count == 3
        #logger.debug "The line we are looking at #{line_split[0][-1]}"
        
        dt = Date.strptime(line_split[0][0],DATE_FORMAT).to_s
        if line_split[0][-1].index("changed") != nil
          #logger.debug "I am inside #{dt} #{from_dt} #{to_dt}" 
          case name[0]
          when 'All'
            if dt >= from_dt and dt <= to_dt
              count += 1
            end
          else
            if name[0] == line_split[0][-1].scan(/(.+)\schanged\s.+/)[0][0] and dt >= from_dt and dt <= to_dt
              count += 1
            end
          end
        end
      end
      #end
    end
    @group_pic_changed = count
    file.close
    #logger.debug "The number of time pic changed #{@group_pic_changed}"
  end
  def get_number_of_times_group_name_changed (from_dt,to_dt,*name)
    count = 0
    file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
    #logger.debug "File Name is #{Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt")}"
    file.each do |line|
      line_split = line.scan(REGEX_ORIGINAL_LINE)
      #if line_split.count != 0
      if line_split[0].count == 3
        #logger.debug "The line we are looking at #{line_split[0][-1]}"
        #logger.debug "The index we are looking at #{line_split[0][-1].index("added")}"
        dt = Date.strptime(line_split[0][0],DATE_FORMAT).to_s
        if line_split[0][-1].index("changed") != nil
          case name[0]
          when 'All'
            if dt >= from_dt and dt <= to_dt
              count += 1
            end
          else
            if name[0] == line_split[0][0] and dt >= from_dt and dt <= to_dt
              count += 1
            end
          end
          #count += 1
        end
      end
      #end
    end
    @group_name_changed = count
    file.close
  end
  def get_number_of_times_group_left (from_dt,to_dt,*name)
    count = 0
    file = File.new(Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt"), "r")
    #logger.debug "File Name is #{Rails.root.join('public', 'uploads', session[:file_name]+"_specific.txt")}"
    file.each do |line|
      line_split = line.scan(REGEX_ORIGINAL_LINE)
      #if line_split.count != 0
      if line_split[0].count == 3
        #logger.debug "The line we are looking at #{line_split[0][-1]}"
        #logger.debug "The index we are looking at #{line_split[0][-1].index("added")}"
        dt = Date.strptime(line_split[0][0],DATE_FORMAT).to_s
        if line_split[0][-1].index("left") != nil
          case name[0]
          when 'All'
            if dt >= from_dt and dt <= to_dt
              count += 1
            end
          else
            if name[0] == line_split[0][-1].scan(/(.+)\sleft/) and dt >= from_dt and dt <= to_dt
              count += 1
            end
          end
        end
      end
      #end
    end
    @group_left = count
    file.close
  end
  def get_summary (file,from_dt,to_dt,*name)

    
    text_hash = JSON.parse(file)
    #read_from_dt = Date.strptime(hsh['date'],'%m/%d/%Y').to_s

    case name[0]
    when 'All'
      @chat_count = text_hash.select {|hsh| Date.strptime(hsh['date'],DATE_FORMAT).to_s >= from_dt and Date.strptime(hsh['date'],DATE_FORMAT).to_s <=to_dt}.count
    else
      @chat_count = text_hash.select {|hsh| hsh["name"] == name[0] and Date.strptime(hsh['date'],DATE_FORMAT).to_s >= from_dt and Date.strptime(hsh['date'],DATE_FORMAT).to_s <=to_dt}.count
    end
  end
end
