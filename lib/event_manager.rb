require "csv"
require "google/apis/civicinfo_v2"
require "erb"
require "time"

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, "0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = "AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw"

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: "country",
      roles: ["legislatorUpperBody", "legislatorLowerBody"],
    ).officials
  rescue
    "You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials"
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir("output") unless Dir.exist?("output")

  filename = "output/thanks_#{id}.html"

  File.open(filename, "w") do |file|
    file.puts form_letter
  end
end

def clean_phone_numbers(phone)
  phone.gsub!(/[^0-9]/, "")
  if phone.length == 11 && phone.to_s[0] == "1"
    phone = phone[1..-1]
  elsif phone.nil? || phone.length < 10 || phone.length >= 11
    "Bad number"
  else
    phone
  end
end

def time_targeting(counter, format)
  string_tabulation = String.new
  counter = counter.sort_by { |key, value| value }.reverse
  counter.each do |key, count|
    if format == "hour"
      string_tabulation += "#{key.rjust(2, "0")}: #{count}
"
    elsif format == "day"
      string_tabulation += "#{key.ljust(10)}: #{count}
"
    end
  end
  string_tabulation
end

puts "EventManager initialized."

contents = CSV.open(
  "event_attendees.csv",
  headers: true,
  header_converters: :symbol,
)

template_letter = File.read("form_letter.erb")
erb_template = ERB.new template_letter
hour_counter = Hash.new(0)
day_counter = Hash.new(0)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  phone = clean_phone_numbers(row[:homephone])

  registration_date = Time.strptime(row[:regdate], "%m/%d/%y %k:%M")
  registration_hour = registration_date.hour
  hour_counter["#{registration_hour}"] += 1

  registration_day = registration_date.strftime("%A")
  day_counter["#{registration_day}"] += 1
end

hour_count = time_targeting(hour_counter, "hour")
day_count = time_targeting(day_counter, "day")
