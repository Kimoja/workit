require_relative "boot"

class MakeCommandsGenerator
  include Utils

  def initialize
    @buffer = {
      functions: [],
      aliases: [],
      helps: {}
    }
  end

  def generate
    collect_commands
    build_script
    write_script
    report
  end

  private

  def collect_commands
    all_commands = get_all_command_classes(Commands)

    all_commands.each do |command_info|
      process_command(command_info)
    end
  end

  def get_all_command_classes(module_obj, prefix = "")
    classes = []

    return classes unless module_obj.respond_to?(:constants)

    module_obj.constants.each do |const_name|
      const = module_obj.const_get(const_name)

      if const.is_a?(Class)
        classes << {
          name: const_name.to_s,
          class: const,
          full_class_name: const.name,
          namespace: extract_namespace_from_class_name(const.name)
        }
      elsif const.is_a?(Module) && const != module_obj
        classes.concat(get_all_command_classes(const, prefix))
      end
    rescue NameError, LoadError => e
      Log.warn "Warning: Could not load #{const_name}: #{e.message}"
    end

    classes
  end

  def extract_namespace_from_class_name(class_name)
    parts = class_name.split('::')
    return "General" if parts.size <= 2

    parts[1..-2].join('::')
  end

  def extract_namespace(full_name)
    parts = full_name.split('::')
    return "General" if parts.size <= 1

    parts[0..-2].join('::')
  end

  def build_full_class_name(module_obj, name)
    "#{module_obj.name}::#{name}".gsub(/^::/, '')
  end

  def process_command(command_info)
    klass = command_info[:class]

    @buffer[:functions] << generate_function(command_info)
    @buffer[:aliases] << generate_aliases(command_info) if klass.respond_to?(:aliases) && klass.aliases&.any?

    namespace = command_info[:namespace]
    @buffer[:helps][namespace] ||= []
    @buffer[:helps][namespace] << generate_help_entry(command_info)
  end

  def generate_function(command_info)
    function_name = command_info[:class].function
    full_class_name = command_info[:full_class_name]

    <<~SHELL
      #{function_name}() {
        local base_dir="$PWD"
        (
          cd "$SCRIPT_DIR"
          bundle exec ruby app.rb "$base_dir" "#{full_class_name}" "$@"
        )
      }
    SHELL
  end

  def generate_aliases(command_info)
    function_name = command_info[:class].function
    aliases = command_info[:class].aliases || []

    aliases.map do |alias_name|
      "alias #{alias_name}='#{function_name}'"
    end.join("\n")
  end

  def generate_help_entry(command_info)
    function_name = command_info[:class].function
    summary = get_summary(command_info[:class])
    aliases = get_aliases(command_info[:class])

    {
      function: function_name,
      summary: summary,
      aliases: aliases
    }
  end

  def get_summary(klass)
    klass.respond_to?(:summary) && klass.summary ? klass.summary : "No description"
  end

  def get_aliases(klass)
    klass.respond_to?(:aliases) && klass.aliases ? klass.aliases : []
  end

  def build_script
    help_content = generate_help_content

    @script_content = <<~SHELL
      #!/bin/bash

      SCRIPT_DIR=$(dirname "$(realpath "$0")")

      #{@buffer[:functions].join("\n")}

      #{@buffer[:aliases].join("\n")}

      workit-help() {
        echo "Available commands:"
        echo ""
      #{help_content}
        echo ""
        echo "Use 'command-name --help' for detailed help on each command"
      }

      alias help='workit-help'
      alias h='workit-help'
    SHELL
  end

  def generate_help_content
    help_lines = []
    sorted_namespaces = @buffer[:helps].keys.sort

    sorted_namespaces.each do |namespace|
      commands = @buffer[:helps][namespace]

      help_lines << "  echo \"#{namespace} Commands:\""

      commands.each do |cmd_info|
        function_name = cmd_info[:function]
        summary = cmd_info[:summary]
        aliases = cmd_info[:aliases]

        help_lines << if aliases.any?
                        "  echo \"    #{function_name} (#{aliases.join(', ')})\""
                      else
                        "  echo \"    #{function_name}\""
                      end

        help_lines << "  echo \"      #{summary}\""
        help_lines << "  echo \"\""
      end

      help_lines << "  echo \"\""
    end

    help_lines.join("\n")
  end

  def write_script
    File.write('commands.sh', @script_content)
    File.chmod(0o755, 'commands.sh')
  end

  def report
    Log.success "Shell script generated: commands.sh"
    Log.pad "Functions generated: #{@buffer[:functions].size}"
    Log.pad "Aliases generated: #{@buffer[:aliases].size}"

    return unless @buffer[:functions].any?

    Log.log "\nGenerated commands by namespace:"
    @buffer[:helps].each do |namespace, commands|
      Log.log "\n#{namespace}:"
      commands.each do |cmd_info|
        aliases_text = cmd_info[:aliases].any? ? " (#{cmd_info[:aliases].join(', ')})" : ""
        Log.log "  #{cmd_info[:function]}#{aliases_text} - #{cmd_info[:summary]}"
      end
    end
  end
end

MakeCommandsGenerator.new.generate
