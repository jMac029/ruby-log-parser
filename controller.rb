class LogParserController

  def initialize
    @log_file = LogFile.new
    @current_view = FileDialogView.new
    @current_view.display @log_file
  end

  def run 
    while user_input = $stdin.getch
      # process the input
      begin
        while next_chars = $stdin.read_nonblock(10)
          user_input = "#{user_input}#{next_chars}"
        end
      rescue IO::WaitReadable
      end
      if @current_view.quittable? && user_input == "\e"
        @current_view.turn_on_cursor
        break
      else
        parse_input user_input
      end
    end
  end

  def parse_input user_input
    case user_input
      when "\n", "\r"
        #change controller likely
        #check the View's current interaction
        #index to see what's next
        case @current_view.class.to_s
	      when 'FileDialogView'
	        file_dialog_select
	      when 'SortFilterView'
	        apply_sort_filter
	      when 'LogListView'
	        display_log_entry
	       end
      when "\e[A"
        #up button update the view with....
        case @current_view.class.to_s
        when 'FileDialogView'
          file_dialog_move -1
        when 'LogListView'
          log_list_move -1
        when 'SortFilterView'
          move_filter_selection -1
       end
      when "\e[B"
	      # down
	      case @current_view.class.to_s
		      when 'FileDialogView'
		        file_dialog_move 1
		      when 'LogListView'
		        log_list_move 1
		      when 'SortFilterView'
		        move_filter_selection 1
	      end
	    when "\t"
	      case @current_view.class.to_s
		      when 'SortFilterView'
		        move_filter_field 1
		    end
	    when "\e[D", "\e[C"
	    # left and right
	    else
	      case @current_view.class.to_s
		      when 'LogListView'
		        sort_select if user_input == 's'
		      when 'LogEntryView'
		        escape_log_entry if user_input == "\e"
		      when 'SortFilterView'
		        if user_input == "\e"
		          escape_sort_filter
		        else
		          input_filter_field user_input
		        end
	     		end
	        # send other input to a selected input field
    end
  end

  def file_dialog_move(increment)
    @log_file.directory_index += increment

    # keep the highlight within bounds
    @log_file.directory_index = 0 if @log_file.directory_index < 0
    @log_file.directory_index = @log_file.directory.entries.length - 1 if @log_file.directory_index > @log_file.directory.entries.length - 1

    # move the list_start variable to the correct place for next screen load of data
    if @log_file.directory_index < @log_file.list_start
      @log_file.list_start = @log_file.directory_index - $stdin.winsize[0] + 3
    elsif @log_file.directory_index > @log_file.list_start + $stdin.winsize[0] - 3
      @log_file.list_start = @log_file.directory_index
    end

    # update the display
    @current_view.update @log_file
  end

  def file_dialog_select
    # create queue to store symbols, :file or :directory
    load_response = Queue.new
    # create a thread to load file data
    load_thread = Thread.new do
      begin
        # store response in queue
        load_response << @log_file.select_directory_or_load_file
      rescue NotAnApacheAccessLog
        @log_file.clear_file
        @current_view.notice 'File does not conform to Access Log pattern'
      rescue NoFileAccess, NoDirAccess
        @log_file.clear_file
        @current_view.notice 'File or Directory Access Not Permitted'
      end
    end
    display_thread = Thread.new do
      # if the load_thread is working ok
      while !load_thread.status.nil? && load_thread.status != false
        # load_thread has initialized the @actual_file
        if @log_file.file_initialized?
          if @log_file.file_percent_loaded != 1
            @current_view.progress_bar @log_file.file_percent_loaded, 'File Loading'
          else
            # display a new progress bar after file is loaded
            # displaying percent of parsing
            @current_view.progress_bar @log_file.parse_percent, 'File Parsing'
          end
        end
        Thread.pass
      end
    end

    # Join threads to ensure processing is complete
    display_thread.join
    load_thread.join

    # if successful there is an object in the queue
    unless load_response.empty?
      case load_response.pop
      when :directory
        @current_view.update @log_file
      when :file
        @current_view = LogListView.new
        @current_view.display @log_file
      end
    end
  end

  def log_list_move(increment)
    @log_file.log_entry_index += increment
    @log_file.log_entry_index = 0 if @log_file.log_entry_index < 0
    @log_file.log_entry_index = @log_file.log_entries.length - 1 if @log_file.log_entry_index > @log_file.log_entries.length - 1
    if @log_file.log_entry_index < @log_file.list_start
      @log_file.list_start = @log_file.log_entry_index - $stdin.winsize[0] + 3
    elsif @log_file.log_entry_index > @log_file.list_start + $stdin.winsize[0] - 3
      @log_file.list_start = @log_file.log_entry_index
    end
    @current_view.update @log_file
  end

  def sort_select
    @current_view = SortFilterView.new
    @current_view.display @log_file.sort_filter
  end

  def escape_sort_filter
    @current_view = LogListView.new
    @current_view.display @log_file
  end

  def move_filter_field(increment)
    @log_file.sort_filter.field_name_index += increment
    if @log_file.sort_filter.field_name_index >= @log_file.sort_filter.field_list.length
      @log_file.sort_filter.field_name_index = 0
    end
    @current_view.update @log_file.sort_filter
  end

  def move_filter_selection(increment)
    current_field = @log_file.sort_filter.field_name_index
    field_list = @log_file.sort_filter.field_list

    if !field_list[current_field][1].nil? && field_list[current_field][1].class != String
      @log_file.sort_filter.field_selection[current_field] += increment
      if @log_file.sort_filter.field_selection[current_field] >= field_list[current_field][1].length
        @log_file.sort_filter.field_selection[current_field] = field_list[current_field][1].length - 1
      end
      @log_file.sort_filter.field_selection[current_field] = 0 if @log_file.sort_filter.field_selection[current_field] < 0
      @current_view.update @log_file.sort_filter
    end
  end

  def input_filter_field(user_input)
    current_field = @log_file.sort_filter.field_name_index
    if @log_file.sort_filter.field_list[current_field][1].nil?
      @log_file.sort_filter.field_list[current_field][1] = user_input
    elsif @log_file.sort_filter.field_list[current_field][1].class == String
      if user_input == "\u007F"
        @log_file.sort_filter.field_list[current_field][1].gsub! /.$/, ''
      else
        @log_file.sort_filter.field_list[current_field][1] += user_input
      end
    end
    @current_view.update @log_file.sort_filter
  end

  def apply_sort_filter
    # Create a thread to load the file data
    load_thread = Thread.new do
      @log_file.log_entries = []
      @log_file.clear_file
      @log_file.select_directory_or_load_file
    end
    # Create a thread to display progress
    display_thread = Thread.new do
      while !load_thread.status.nil? && load_thread.status != false
        if @log_file.file_initialized?
          if @log_file.file_percent_loaded != 1
            @current_view.progress_bar @log_file.file_percent_loaded, 'File Loading'
          else
            @current_view.progress_bar @log_file.parse_percent, 'File Parsing'
          end
        end
        Thread.pass
      end
    end
    # join the threads to ensure processing is complete
    display_thread.join
    load_thread.join

    # apply the filters and sorting
    begin
      @log_file.sort_filter.apply_selections @log_file
      @current_view = LogListView.new
      @current_view.display @log_file
    rescue IPAddr::InvalidAddressError
      @current_view.notice 'Please input a valid IP address'
    rescue InvalidDate
      @current_view.notice "Please input a date and time 'MM-DD HH:MM:SS'"
    end
  end

  #######################
  # Output one line of
  # the log on one screen
  #######################
  def display_log_entry
    @current_view = LogEntryView.new
    @current_view.display @log_file
  end

  ####################
  # return to log list
  ####################
  def escape_log_entry
    @current_view = LogListView.new
    @current_view.display @log_file
  end

end
