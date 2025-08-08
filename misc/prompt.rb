def yes_no(text:, yes: nil, no: nil)
  # play_promt_sound
  
  log "#{text} (y/N): "

  response = STDIN.gets.chomp.downcase

  if response == 'y' || response == 'yes'
    yes&.call
  else
    no&.call
  end
# rescue Errno::ENOENT => e
#   binding.pry
#   puts "Error reading input: #{e.message}"
#   puts "Defaulting to 'no'"
#   'no'
# rescue => e
#   puts "Unexpected error: #{e.message}"
#   'no'
end
