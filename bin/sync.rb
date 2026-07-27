#!/usr/bin/env ruby
require 'yaml'
require 'json'

def derive_clean_word(word)
  word.unicode_normalize(:nfd).gsub(/\p{M}/, '').downcase.gsub(/[^a-z0-9]/, '').strip
end

def title_case(word)
  w = word.strip
  w[0].upcase + w[1..-1].downcase
end

words_path = File.join(__dir__, '..', 'words.yaml')
words = YAML.load_file(words_path)

updated_words = words.map do |entry|
  # 1. Format word to title case
  entry['word'] = title_case(entry['word'])
  
  # 2. Derive clean word
  word_clean = derive_clean_word(entry['word'])
  entry['word_clean'] = word_clean
  
  # 3. Update image path
  entry['image_path'] = "assets/images/#{entry['date']}-#{word_clean}.png"
  
  # 4. Check if audio file exists and set path accordingly
  aud_path = "assets/audio/#{entry['date']}-#{word_clean}.ogg"
  if File.exist?(File.join(__dir__, '..', aud_path))
    entry['audio_path'] = aud_path
  else
    entry['audio_path'] = nil
  end
  
  entry
end

# Write back to words.yaml
File.write(words_path, YAML.dump(updated_words), encoding: 'utf-8')
puts "Successfully cleaned and updated words.yaml!"

# Sort for index.html (descending by date)
sorted_words = updated_words.sort_by { |w| w['date'] }.reverse

# Format as JSON string for index.html
json_data = JSON.pretty_generate(sorted_words)

html_path = File.join(__dir__, '..', 'index.html')
html = File.read(html_path, encoding: 'utf-8')

# Replace the const data array
updated_html = html.sub(/(const data =\s*\[).*?(\n\s*\];)/m, "const data = #{json_data};")

File.write(html_path, updated_html, encoding: 'utf-8')
puts "Successfully synchronized index.html!"
