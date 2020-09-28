# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def clean_phone_number(phone_number)
  digits_only = phone_number.scan(/\d/).join('')
  if digits_only.size == 10
    digits_only
  elsif digits_only.size == 11 && digits_only[0] == '1'
    digits_only.slice(1..9)
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist? 'output'

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def registration_date_string_to_datetime(reg_date)
  DateTime.strptime(reg_date, '%m/%d/%y %H:%M')
end

def count_occurrences_of(array)
  array.each_with_object(Hash.new(0)) do |item, collector|
    collector[item] += 1
  end
end

def find_most_common(array, places)
  sorted_and_grouped_array = []
  sorted_array = count_occurrences_of(array).sort_by { |_key, value| value }
  until sorted_and_grouped_array.size == places
    local_max = sorted_array.select { |kv| kv.last == sorted_array.last.last }
    sorted_array.pop(local_max.size)
    sorted_and_grouped_array.push(local_max)
  end
  sorted_and_grouped_array
end

def print_most_common(array, places, label)
  find_most_common(array, places).each_with_index do |place, index|
    keys = place.map(&:first)
    if index.zero?
      puts "Most common #{label}: #{keys} with value #{place.flatten.last}"
    else
      puts "Next most common #{label}: #{keys} with value #{place.flatten.last}"
    end
  end
end

puts 'EventManager Initialized!'

contents = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

template_letter = File.read 'form_letter.erb'
erb_template = ERB.new template_letter

phone_numbers = []
registration_hours = []
registration_days = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  phone_numbers.push(phone_number)
  legislators = legislators_by_zipcode(zipcode)
  registration_date = registration_date_string_to_datetime(row[:regdate])
  registration_hours.push(registration_date.hour)
  registration_days.push(registration_date.strftime('%A'))

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

print_most_common(registration_hours, 3, 'hour/hours')
print_most_common(registration_days, 3, 'weekday/weekdays')
