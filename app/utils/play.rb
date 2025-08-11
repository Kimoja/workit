module Utils
  module Play
    extend self

    def promt
      case RUBY_PLATFORM
      when /darwin/ # macOS
        system('afplay /System/Library/Sounds/Glass.aiff > /dev/null 2>&1 &')
      when /linux/
        # Try different Linux sound commands
        system('paplay /usr/share/sounds/alsa/Front_Left.wav > /dev/null 2>&1 &') ||
          system('aplay /usr/share/sounds/alsa/Front_Left.wav > /dev/null 2>&1 &') ||
          system('speaker-test -t sine -f 1000 -l 1 > /dev/null 2>&1 &') ||
          system("echo -e '\\a'") # Fallback to terminal bell
      when /mswin|mingw|cygwin/ # Windows
        system("powershell -c '[console]::beep(800,200)' > nul 2>&1 &")
      else
        # Fallback: terminal bell character
        print "\a"
      end
    rescue StandardError
      # Silent fallback if sound fails
      print "\a"
    end

    def error
      case RUBY_PLATFORM
      when /darwin/ # macOS
        system('afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &')
      when /linux/
        # Try different Linux sound commands with error-like frequency
        system('speaker-test -t sine -f 400 -l 1 > /dev/null 2>&1 &') ||
          system('paplay /usr/share/sounds/alsa/Front_Left.wav > /dev/null 2>&1 &') ||
          system('aplay /usr/share/sounds/alsa/Front_Left.wav > /dev/null 2>&1 &') ||
          system("echo -e '\\a'") # Fallback to terminal bell
      when /mswin|mingw|cygwin/ # Windows
        system("powershell -c '[console]::beep(400,300)' > nul 2>&1 &")
      else
        # Fallback: terminal bell character
        print "\a"
      end
    rescue StandardError
      # Silent fallback if sound fails
      print "\a"
    end
  end
end
