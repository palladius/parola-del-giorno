require 'minitest/autorun'
require 'yaml'

class TestIntegrity < Minitest::Test
  def setup
    @words = YAML.load_file(File.join(__dir__, '..', 'words.yaml'))
  end

  def test_no_duplicate_words
    word_list = @words.map { |w| w['word'].strip.upcase }
    duplicates = word_list.select { |w| word_list.count(w) > 1 }.uniq
    assert_empty duplicates, "Trovate parole duplicate nel registro: #{duplicates.join(', ')}"
  end

  def test_assets_existence
    @words.each do |entry|
      img_path = File.join(__dir__, '..', entry['image_path'])
      assert File.exist?(img_path), "Immagine mancante per '#{entry['word']}': #{img_path}"
      
      if entry['audio_path']
        aud_path = File.join(__dir__, '..', entry['audio_path'])
        assert File.exist?(aud_path), "Audio mancante per '#{entry['word']}': #{aud_path}"
      end
    end
  end
end
