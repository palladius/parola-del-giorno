require 'minitest/autorun'
require 'yaml'
require 'json'

class TestIntegrity < Minitest::Test
  def setup
    @words_path = File.expand_path('../words.yaml', __dir__)
    @words = YAML.load_file(@words_path)
    
    @html_path = File.expand_path('../index.html', __dir__)
    @html_content = File.read(@html_path, encoding: 'utf-8')
    
    # Extract data array from index.html using a robust regex matching until const grid
    json_match = @html_content.match(/const data =\s*(\[.*?\n\]);\s*const/m)
    if json_match
      @index_data = JSON.parse(json_match[1])
    else
      @index_data = []
    end
  end

  # Helpers
  def derive_clean_word(word)
    word.unicode_normalize(:nfd).gsub(/\p{M}/, '').downcase.gsub(/[^a-z0-9]/, '').strip
  end

  # 1. HTML-YAML Synchronization Test
  def test_index_html_in_sync_with_words_yaml
    refute_empty @index_data, "Impossibile estrarre l'array data da index.html"
    assert_equal @words.size, @index_data.size, "Numero di voci differente tra words.yaml (#{@words.size}) e index.html (#{@index_data.size})"
    
    @words.each do |yaml_entry|
      html_entry = @index_data.find { |i| i['word'] == yaml_entry['word'] }
      refute_nil html_entry, "La parola '#{yaml_entry['word']}' è presente in words.yaml ma non in index.html"
      
      %w[word word_clean date description image_path audio_path].each do |key|
        if yaml_entry[key].nil?
          assert_nil html_entry[key], "Mismatch per la parola '#{yaml_entry['word']}' per il campo '#{key}' (atteso nil)"
        else
          assert_equal yaml_entry[key], html_entry[key], "Mismatch per la parola '#{yaml_entry['word']}' per il campo '#{key}'"
        end
      end
    end
  end

  # 2. Casing test (No ALL CAPS words allowed)
  def test_no_uppercase_words
    @words.each do |entry|
      word = entry['word'].strip
      # A word is in all caps if it equals its uppercase version, and contains letters
      is_all_caps = (word == word.upcase && word.match?(/[A-Z]/))
      refute is_all_caps, "La parola '#{word}' è scritta interamente in MAIUSCOLO! Deve essere in Title Case (es. 'Infinocchiàre')."
    end
  end

  # 3. Duplicate checks
  def test_no_duplicates
    # Check duplicate words (normalized/accent-insensitive)
    word_list = @words.map { |w| derive_clean_word(w['word']) }
    duplicates = word_list.select { |w| word_list.count(w) > 1 }.uniq
    assert_empty duplicates, "Parole duplicate trovate nel registro: #{duplicates.join(', ')}"
    
    # Check duplicate dates
    date_list = @words.map { |w| w['date'].strip }
    duplicate_dates = date_list.select { |d| date_list.count(d) > 1 }.uniq
    assert_empty duplicate_dates, "Date duplicate trovate nel registro: #{duplicate_dates.join(', ')}"
    
    # Check duplicate word_clean fields
    clean_list = @words.map { |w| w['word_clean'] }.compact
    duplicate_cleans = clean_list.select { |c| clean_list.count(c) > 1 }.uniq
    assert_empty duplicate_cleans, "word_clean duplicati nel registro: #{duplicate_cleans.join(', ')}"

    # Check duplicate image paths
    img_list = @words.map { |w| w['image_path'] }.compact
    duplicate_imgs = img_list.select { |i| img_list.count(i) > 1 }.uniq
    assert_empty duplicate_imgs, "Percorsi immagini duplicati nel registro: #{duplicate_imgs.join(', ')}"

    # Check duplicate audio paths
    aud_list = @words.map { |w| w['audio_path'] }.compact
    duplicate_auds = aud_list.select { |a| aud_list.count(a) > 1 }.uniq
    assert_empty duplicate_auds, "Percorsi audio duplicati nel registro: #{duplicate_auds.join(', ')}"
  end

  # 4. Asset validity and filenames tests
  def test_assets_integrity_and_naming
    @words.each do |entry|
      word = entry['word']
      word_clean = entry['word_clean']
      date = entry['date']
      
      # Derive non-accented word
      expected_clean = derive_clean_word(word)
      assert_equal expected_clean, word_clean, "Il campo word_clean per '#{word}' non è coerente. Atteso: #{expected_clean}, trovato: #{word_clean}"
      
      # 1. Validate Image
      img_path = entry['image_path']
      refute_nil img_path, "image_path mancante per la parola '#{word}'"
      
      # Check filename naming convention: must contain the same non-accented word
      expected_img_name = "#{date}-#{word_clean}.png"
      actual_img_name = File.basename(img_path)
      assert_equal expected_img_name, actual_img_name, "Il nome del file immagine per '#{word}' deve corrispondere alla parola senza accenti: atteso '#{expected_img_name}', trovato '#{actual_img_name}'"
      
      abs_img_path = File.expand_path(File.join(__dir__, '..', img_path))
      assert File.exist?(abs_img_path), "File immagine mancante per '#{word}': #{img_path}"
      assert File.size(abs_img_path) > 100, "File immagine vuoto o corrotto per '#{word}': #{img_path}"
      
      # Check image magic bytes
      magic_bytes = File.binread(abs_img_path, 8)
      assert_equal "\x89PNG\r\n\x1a\n".b, magic_bytes, "Il file immagine per '#{word}' non è un PNG valido: #{img_path}"

      # 2. Validate Audio (if present)
      if entry['audio_path']
        aud_path = entry['audio_path']
        
        # Check filename naming convention: must contain the same non-accented word
        expected_aud_name = "#{date}-#{word_clean}.ogg"
        actual_aud_name = File.basename(aud_path)
        assert_equal expected_aud_name, actual_aud_name, "Il nome del file audio per '#{word}' deve corrispondere alla parola senza accenti: atteso '#{expected_aud_name}', trovato '#{actual_aud_name}'"
        
        abs_aud_path = File.expand_path(File.join(__dir__, '..', aud_path))
        assert File.exist?(abs_aud_path), "File audio mancante per '#{word}': #{aud_path}"
        assert File.size(abs_aud_path) > 1000, "File audio vuoto o troppo piccolo per '#{word}': #{aud_path}"
        
        # Check audio magic bytes
        ogg_magic = File.binread(abs_aud_path, 4)
        assert_equal "OggS".b, ogg_magic, "Il file audio per '#{word}' non è un OGG/Opus valido: #{aud_path}"
        
        # Verify duration > 1.5 seconds using ffprobe if available
        ffprobe_path = `which ffprobe`.strip
        unless ffprobe_path.empty?
          duration_str = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{abs_aud_path}"`.strip
          duration = duration_str.to_f
          assert duration > 1.5, "Il file audio per '#{word}' è troppo breve (#{duration}s, atteso > 1.5s): #{aud_path}"
        end
      end
    end
  end

  # 5. Dead assets check (every image and audio file must be referenced)
  def test_no_unreferenced_assets
    referenced_images = @words.map { |w| w['image_path'] }.compact.map { |p| File.expand_path(File.join(__dir__, '..', p)) }
    referenced_audios = @words.map { |w| w['audio_path'] }.compact.map { |p| File.expand_path(File.join(__dir__, '..', p)) }
    
    actual_images = Dir.glob(File.join(__dir__, '../assets/images/*')).select { |f| File.file?(f) && File.basename(f) != '.gitkeep' }.map { |f| File.expand_path(f) }
    actual_audios = Dir.glob(File.join(__dir__, '../assets/audio/*')).select { |f| File.file?(f) && File.basename(f) != '.gitkeep' }.map { |f| File.expand_path(f) }
    
    unreferenced_images = actual_images - referenced_images
    unreferenced_audios = actual_audios - referenced_audios
    
    assert_empty unreferenced_images, "Immagini orfane (non referenziate in words.yaml) trovate: #{unreferenced_images.map{|f| File.basename(f)}.join(', ')}"
    assert_empty unreferenced_audios, "Audio orfani (non referenziati in words.yaml) trovati: #{unreferenced_audios.map{|f| File.basename(f)}.join(', ')}"
  end
end
