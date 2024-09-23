# frozen_string_literal: true

require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'

puts 'EventManager initialized.'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  digits = phone_number.gsub(/[^0-9]/, '')

  if digits.length == 10
    "(#{digits[0..2]}) #{digits[3..5]}-#{digits[6..9]}"
  elsif digits.length == 11 && digits[0] == '1'
    "(#{digits[1..3]}) #{digits[4..6]}-#{digits[7..10]}"
  else
    'Your phone number is incorrect'
  end
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = File.read('secret.key').strip
  civic_info.representative_info_by_address(
    address: zipcode,
    levels: 'country',
    roles: %w[legislatorUpperBody legislatorLowerBody]
  ).officials
rescue StandardError
  'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

def get_registration_pick_hour(hours)
  pick_hours = hours.tally
  pick_hour = pick_hours.max_by { |_hour, value| value }.first
  p "peak registration hour is #{pick_hour}"
end

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

registration_hours = []
contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  phone_number = clean_phone_number(row[:homephone])
  legislators = legislators_by_zipcode(zipcode)

  registration_hours.push(Time.strptime(row[:regdate], '%m/%d/%y %H:%M').hour)
  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{name} - #{zipcode} - #{phone_number}"
end

get_registration_pick_hour(registration_hours)
