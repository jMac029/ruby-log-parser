class BasicView

  def clear_display
    print "\e[2j"
  end

  def red(text)
    "\e[31;40m#{text}\e[0m"
  end

  def turn_off_cursor
    print "\e[?25l"
  end

  def turn_on_cursor
    print "\e[?25h"
  end

  def set_cursor(row = 1, column = 1)
    print "\e[#{row};#{column}H"
  end

  def center(text)
    columns = $stdin.winsize[1]
    text_length = text.length
    column_location = columns / 2 - text_length / 2
    text = "\e[#{column_location}G#{text}"
  end

  def notice(message)
    set_cursor $stdin.winsize[0], 1
    print "\e[K" + red(message)
  end

  def progress_bar(percent, label = 'Loading')
    set_cursor $stdin.winsize[0], 1
    label_line = label + ' ['
    print label_line
    length = percent * ($stdin.winsize[1] - label_line.length + 1)
    bar = '*' * length
    print bar + "\e[K"
    set_cursor $stdin.winsize[0], $stdin.winsize[1]
    print ']'
  end

end


class FileDialogView < BasicView
  def display(log_file)
    clear_display
    turn_off_cursor
    set_cursor
    puts red(center('Select an Apache log file.'))
    update log_file
  end

  def update(log_file)
    set_cursor 2, 1
    log_file.directory.each_with_index do |directory_entry, index|
      if index < log_file.list_start
        next
      end
      if index > log_file.list_start + $stdin.winsize[0] - 3
        break
      end
      directory_entry += '/' if Dir.exist?(log_file.file_path + directory_entry)
      directory_entry = red(directory_entry) if index == log_file.directory_index
      print directory_entry + "\e[K\n"
    end
    print "\e[J"
    set_cursor $stdin.winsize[0], 1
    print red("Type 'q' to exit; up/down to move; return to select")
  end

  def quittable?
    true
  end
end

class LogListView < BasicView
  def display(log_file)
    clear_display
    set_cursor
    print red(center(log_file.file_name)) + "\n"
    update log_file
  end

  def update(log_file)
    set_cursor 2, 1
    log_file.log_entries.each_with_index do |entry, index|
      next if index < log_file.list_start

      break if index > log_file.list_start + $stdin.winsize[0] - 3

      total_columns = $stdout.winsize[1] - 44 # (space after ip address, response code, and file size)
      text_column_size = total_columns / 3
      row = "\e[K" + entry.time_stamp.strftime('%m-%d %H:%M:%S') +
            "\e[16G" + entry.ip_address.to_s +
            "\e[#{17 + 16}G" + entry.request.slice(0, text_column_size) +
            "\e[#{text_column_size + 17 + 1 + 16}G" + entry.response_code +
            "\e[#{text_column_size + 17 + 1 + 4 + 16}G" + entry.http_referer.slice(0, text_column_size) +
            "\e[#{2 * text_column_size + 17 + 2 + 4 + 16}G" + entry.user_agent.slice(0, text_column_size) +
            "\e[#{3 * text_column_size + 17 + 3 + 4 + 16}G" + entry.file_size.slice(0, 7) + "\n"
      row = red(row) if index == log_file.log_entry_index
      print row
    end
    print "\e[J"
    set_cursor $stdin.winsize[0], 1
    print red("Esc to exit, up/down to move, 's' to sort or filter, Return to see the full entry")
  end

  def quittable?
    true
  end
end

class SortFilterView < BasicView
  def quittable?
    false
  end

  def display(sort_filter)
    clear_display
    set_cursor
    print red(center('Sort and Filter'))
    update sort_filter
  end

  def update(sort_filter)
    set_cursor 2, 1

    #----Loop through outer field_list array [a] => the fields----#
    sort_filter.field_list.each_with_index do |field_name, index|
      #---- if this is nil or String then it's an input field and not a choice box-----#
      if !field_name[1].nil? && field_name[1].class != String
        #----Display the choice box----#
        label = field_name[0].to_s.tr('_', ' ').upcase + ':'
        label = red(label) if index == sort_filter.field_name_index
        puts label
        field_name[1].each_with_index do |option, opt_index|
          option = red(option) if opt_index == sort_filter.field_selection[index]
          puts "\e[K" + option.to_s
        end
        print "\e[K\n\e[K\n"
      else
        #-----Display the input field----#
        # These are typed input fields
        input = ''
        input = field_name[1] unless field_name[1].nil?
        row = "Show only records where #{field_name[0].to_s.tr('_', ' ').upcase} contains: #{input}"
        row = red(row) if index == sort_filter.field_name_index
        puts "\e[K" + row
        end
    end
    print "\e[J"
    set_cursor $stdin.winsize[0], 1
    print red('Esc to return, Move up/down to select, Tab to change focus, Return to Apply')
  end

end

class LogEntryView < BasicView
  def quittable?
    false
  end

  def display(log_file)
    entry = log_file.log_entries[log_file.log_entry_index]
    clear_display
    set_cursor
    print red(center("Displaying Entry #: #{log_file.log_entry_index + 1}"))
    set_cursor 3, 1
    print "Time:         \t#{entry.time_stamp}\n"
    print "IP:           \t#{entry.ip_address}\n"
    print "Request:      \t#{entry.request}\n"
    print "Response:     \t#{entry.response_code}\n"
    print "File Size:    \t#{entry.file_size}\n"
    print "HTTP Referer: \t#{entry.http_referer}\n"
    print "User Agent:   \t#{entry.user_agent}\n"
    print "\e[J"
    set_cursor $stdin.winsize[0], 1
    print red('Esc to return to List View')
  end
end
