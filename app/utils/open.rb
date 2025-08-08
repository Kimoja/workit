# rubocop:disable Layout/LineLength
module Utils
  module Open
    extend self

    def browser(url)
      Log.info "Opening #{url} in browser..."

      case RUBY_PLATFORM
      when /darwin/ # macOS
        system("open '#{url}'")
      when /linux/
        system("xdg-open '#{url}'")
      when /mswin|mingw|cygwin/ # Windows
        system("start '#{url}'")
      else
        Log.log "Please open the following URL in your browser: #{url}"
      end
    rescue StandardError => e
      Log.error "Failed to open browser: #{e.message}"
    end

    def file_explorer(path)
      Log.info "Opening #{path} in file explorer..."

      # Vérifier que le chemin existe
      unless File.exist?(path)
        Log.error "Path does not exist: #{path}"
        return
      end

      case RUBY_PLATFORM
      when /darwin/ # macOS
        system("open '#{path}'")
      when /linux/
        system("xdg-open '#{path}'")
      when /mswin|mingw|cygwin/ # Windows
        # Utiliser explorer.exe pour Windows
        if File.directory?(path)
          system("explorer '#{path.gsub('/', '\\')}'")
        else
          # Pour un fichier, ouvrir le dossier parent et sélectionner le fichier
          system("explorer /select,'#{path.gsub('/', '\\')}'")
        end
      else
        Log.log "Please open the following path manually: #{path}"
      end
    rescue StandardError => e
      Log.error "Failed to open file explorer: #{e.message}"
    end

    def file_code(path)
      Log.info "Opening #{path} in VS Code..."

      unless File.exist?(path)
        Log.error "Path does not exist: #{path}"
        return
      end

      # Essayer d'ouvrir avec VS Code
      success = false

      case RUBY_PLATFORM
      when /darwin/ # macOS
        # Essayer différentes commandes VS Code sur macOS
        success = system("code '#{path}' 2>/dev/null") ||
                  system("/usr/local/bin/code '#{path}' 2>/dev/null") ||
                  system("/Applications/Visual\\ Studio\\ Code.app/Contents/Resources/app/bin/code '#{path}' 2>/dev/null") ||
                  system("open -a 'Visual Studio Code' '#{path}' 2>/dev/null")

      when /linux/
        # Essayer différentes commandes VS Code sur Linux
        success = system("code '#{path}' 2>/dev/null") ||
                  system("/usr/bin/code '#{path}' 2>/dev/null") ||
                  system("/snap/bin/code '#{path}' 2>/dev/null") ||
                  system("flatpak run com.visualstudio.code '#{path}' 2>/dev/null")

      when /mswin|mingw|cygwin/ # Windows
        windows_path = path.gsub('/', '\\')

        # Essayer différentes commandes VS Code sur Windows
        success = system("code \"#{windows_path}\" 2>nul") ||
                  system("\"C:\\Program Files\\Microsoft VS Code\\bin\\code.cmd\" \"#{windows_path}\" 2>nul") ||
                  system("\"C:\\Users\\#{ENV.fetch('USERNAME',
                                                   nil)}\\AppData\\Local\\Programs\\Microsoft VS Code\\bin\\code.cmd\" \"#{windows_path}\" 2>nul")

      else
        Log.error "Unsupported platform: #{RUBY_PLATFORM}"
        return
      end

      unless success
        Log.error "VS Code not found or failed to open. Please install VS Code and ensure 'code' command is available in PATH"
        Log.log "You can install the 'code' command by:"
        Log.log "- macOS: Open VS Code → Command Palette → 'Shell Command: Install code command in PATH'"
        Log.log '- Linux: Usually available after installation'
        Log.log '- Windows: Should be available after installation'
        nil
      end
    rescue StandardError => e
      Log.error "Failed to open VS Code: #{e.message}"
    end
  end
end
# rubocop:enable Layout/LineLength
