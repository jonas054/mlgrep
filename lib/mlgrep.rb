# encoding: utf-8

require 'pathname'
require 'yaml'

MLGREP_HOME = File.dirname(Pathname.new(__FILE__).realpath)

# Path for any_white_space.rb, skip_stuff.rb, and (indirectly) fsm.rb
$:.unshift MLGREP_HOME

require 'any_white_space'
require 'skip_stuff' # String#without{Xml|Script|Python|Cpp}{Comments|Strings}

LANGUAGES = {
  '-W' => { glob: '{*,.*}' },
  '-P' => { glob: '*.py',                              hashbang: /python/i },
  '-R' => { glob: '{*.{rb,gemspec},Rakefile,Gemfile}', hashbang: /ruby/i   },
  '-L' => { glob: '*.{pl,PL,pm,pod,t}',                hashbang: /perl/i   },
  '-C' => { glob: '*.{cc,c,cpp}'                                           },
  '-H' => { glob: '*.{hh,h,hpp}'                                           },
  '-J' => { glob: '*.java'                                                 },
  '-E' => { glob: '*.js'                     }, # E is for ECMAScript
  '-V' => { glob: '[0-9]*'                                                 },
  '-T' => { glob: '*.{html,htm,xhtml,xml,css}'                             },
  '-M' => { glob:
    '{*.cmake,CMakeLists.txt,Makefile,Makefile.old,makefile,*.mak,*.mk,*.make}' }
}

def mlgrep(*args)
  catch(:exit) {
    $anything_found = false
    begin
      parameters = gather_parameters args
      search parameters
    rescue RuntimeError => e
      $stderr.puts e.message
      return 1
    end

    if parameters[:flags][:statistics]
      print_statistics parameters[:regexp_to_find]
    end
    return $anything_found ? 0 : 1
  }
  1 # We end up here because of throw :exit, so it's an error.
end

def gather_parameters(args)
  args_after_options, normalized_args, flags, patterns, exclude_regexen =
    parse_args args

  if flags[:statistics]
    $match_statistics = Hash.new 0
    $file_statistics  = Hash.new 0
  end

  Doc.usage if flags[:help]
  Doc.short_usage 'No regexp was given.' if args_after_options.empty?

  # Work with duplicate of argument in case args_after_options are frozen.
  regexp_to_find = make_regex args_after_options.shift.dup, flags

  exclude_regexen << /\b#{regexp_to_find.source}\b/ if flags[:exclude_self]

  { files_and_dirs:  args_after_options.exclude(exclude_regexen),
    normalized_args: normalized_args,
    flags:           flags,
    patterns:        patterns,
    exclude_regexen: exclude_regexen,
    regexp_to_find:  regexp_to_find }
end

def search(parameters)
  files = parameters[:files_and_dirs].reject { |e|
    File.directory? e
  }.flatten.uniq
  mlgrep_search_files($stdout, parameters[:regexp_to_find], files,
                      parameters[:flags])
  if parameters[:patterns].any?
    search_recursively_by_patterns parameters
  elsif parameters[:files_and_dirs].empty? ||
      parameters[:files_and_dirs] == ['/dev/null']
    if parameters[:exclude_regexen].any?
      Doc.short_usage('Exclusion flag (-x or -X) but no pattern flag ' +
                      '(' + LANGUAGES.keys.sort.join(',') +
                      ',-S,-r) or file list')
    end

    # If no filenames were given, mlgrep is used in pipe mode. Just print
    # the match.
    $stdin.read.multiline_grep('STDIN', :raw, parameters[:regexp_to_find],
                               parameters[:flags]) do |line_nr, match|
      $anything_found = true
      if parameters[:flags][:statistics]
        $match_statistics[match] += 1
        $file_statistics['STDIN'] += 1
      else
        puts match
      end
    end
  end
end

def search_recursively_by_patterns(parameters)
  require 'find'
  dirs = parameters[:files_and_dirs].select { |e| File.directory? e }
  dirs = ['.'] if dirs.empty?
  dirs.each { |dir|
    Find.find dir do |f|
      Find.prune if f =~ /\.(snapshot|svn)/ || f =~ /~$/ || f =~ /_flymake/
      Find.prune if parameters[:exclude_regexen].find { |re| f =~ re }

      if File.directory?(f) && !File.symlink?(f)
        f = f.realpath if parameters[:flags][:absolute_paths]
        files = parameters[:patterns].map { |p|
          all = Dir[File.join(f, p)].exclude parameters[:exclude_regexen]
          all.reject { |e| File.directory? e }
        }
        files << hashbang_matches(parameters[:normalized_args], f)
        mlgrep_search_files($stdout, parameters[:regexp_to_find],
                            files.flatten.uniq, parameters[:flags])
      end
    end
  }
end

SIMPLE_FLAGS = {
  '-a' => :absolute_paths,
  '-c' => :no_comments,
  '-e' => :exclude_self,
  '-g' => :ignore_errors,
  '-h' => :help,
  '-i' => :ignore_case,
  '-j' => :intellij,
  '-k' => :statistics,
  '-l' => :list,
  '-n' => :line,
  '-N' => :no_line_nr,
  '-o' => :only_match,
  '-s' => :no_strings,
  '-w' => :whole_word
}

SIMPLE_FLAGS_REGEX = /-[#{SIMPLE_FLAGS.keys.join.gsub '-', ''}]/

def parse_args(args)
  patterns, exclude_regexen = [], []

  flags = {}
  normalized_args = normalize_args(args)
  args = normalized_args.dup
  # Default mlgrep.yml file. May be changed by -f.
  cfg_file = File.join(ENV['HOME'] || ENV['HOMEDRIVE'], '.mlgrep.yml')

  while args.first =~ /^-/
    check_if_illegal_combination(args)

    case args.shift
      # Files to include/exclude
    when /^-[CEHJLMPRVW]$/ then patterns << LANGUAGES[$&][:glob]
    when '-S' then patterns << get_property('source', cfg_file)
    when '-r' then patterns << args.shift
    when '-f' then cfg_file = args.shift
    when '-x' then exclude_regexen << Regexp.new(args.shift)
    when '-X'
      re = get_property 'exclude', cfg_file
      exclude_regexen << Regexp.new(re) unless re.empty?
      # Flags
    when SIMPLE_FLAGS_REGEX then flags[SIMPLE_FLAGS[$&]] = true
    when /-q(\d+)?/         then flags[:quiet] = Integer($1 || 20)
    when /.*/               then Doc.short_usage "Unknown flag: #{$&}."
    end
  end
  flags_in_args = args.grep(/^-/)
  if flags_in_args.any?
    Doc.short_usage "Flag #{flags_in_args.first} encountered after regexp"
  end
  flags.freeze
  [args, normalized_args.grep(/^-/), flags, patterns, exclude_regexen]
end

def normalize_args(args)
  args.map { |arg|
    if arg =~ /^-([a-z]{2,})$/i
      # Break up compound flags, e.g., "-nsi" => "-n", "-s", "-i"
      $1.split(//).map { |x| "-#{x}" }
    else
      arg
    end
  }.flatten
end

def check_if_illegal_combination(args)
  %w(ln lN lq lo lk).each { |combo|
    opt = args.grep %r"^-[#{combo}]"
    Doc.short_usage "Can't combine #{opt * ' '}." if opt.size > 1
  }
end

def print_statistics(regexp_to_find)
  print_table $file_statistics
  puts '-' * 50
  print_table $match_statistics
  total = $match_statistics.values.inject(0) { |sum, count| sum + count }
  printf "%5d TOTAL /%s/\n", total, regexp_to_find.source
end

def print_table(table)
  table.sort.each { |key, count|
    key = %Q{"#{key}"} if key =~ /\s+$/
    puts '%5d %s' % [count, key]
  }
end

def get_property(name, cfg_file)
  create_default_config_file(cfg_file) unless File.exist? cfg_file
  cfg = YAML.load_file(cfg_file)
  cfg[name] or fail "No line starting with #{name}: found in #{cfg_file}"
end

def create_default_config_file(cfg_file)
  File.open(cfg_file, 'w') { |f|
    f.puts '# Glob pattern for files to find with the -S flag.'
    f.puts("source: '{*.{cc,c,cpp,hh,h,hpp,java,js,pl,PL,pm,pod,t,py,rb," +
           "cmake,rhtml,erb,yml},CMakeLists.txt}'")
    f.puts("# Regular expression for files and directories to exclude with " +
           "the -X flag.")
    f.puts "exclude: '.svn/'"
  }
end

def make_regex(re_string, flags)
  # Special regexp \u (until)
  re_string.gsub!(/\\u\[(.*?[^\\])\]/, '[^\1]*[\1]')
  re_string.gsub!(/\\u(\\?.)/, '[^\1]*\1')

  # Expressions like [^\n]* are ok in -n mode so we filter out negative REs.
  if flags[:line] and re_string.gsub(/\[\^.*?[^\\]\]/, '').index('\n')
    Doc.short_usage "Don't use \\n in regexp when in line mode (-n)"
  end

  re_string = "\\b(?:#{re_string})\\b" if flags[:whole_word]
  if flags[:line]
    re_string = '^.*' + re_string + '.*[\n$]'
    re_flags = 0
  else
    re_flags = Regexp::MULTILINE
  end
  re_flags |= Regexp::IGNORECASE if flags[:ignore_case]

  Regexp.new(re_string, re_flags).any_white_space
end

def mlgrep_search_files(output, re, names, flags = {})
  names = names.reject { |name| File.symlink? name or File.directory? name }
  names.each { |filename|
    begin
      text = IO.read filename
    rescue Errno::ENOENT, Errno::EINVAL, Errno::EIO, Errno::ENXIO, Errno::EACCES => e
      $stderr.puts "mlgrep: #{e}"
      next
    end
    filename = filename.realpath if flags[:absolute_paths]

    text.multiline_grep filename, :strip, re, flags do |line_nr, match|
      if flags[:intellij] and $anything_found
        print "Press <RETURN> to continue"
        $stdin.gets
      end
      $anything_found = true
      if flags[:statistics]
        $match_statistics[match] += 1
        $file_statistics[filename] += 1
      else
        if flags[:list]
          puts filename
          break
        end

        match = text.split(/\n/)[line_nr - 1].strip if flags[:line]
        output << "#{filename}:#{line_nr}: " unless flags[:no_line_nr]
        yield filename, line_nr, match if block_given?
        output << match << "\n"
        system "idea #{filename}:#{line_nr}" if flags[:intellij]
      end
    end
  }
end

module Enumerable
  # Rejects all elements matching any of the given regexen.
  def exclude(regexen)
    reject { |name| regexen.find { |re| name =~ re } }
  end
end

class Doc
  README = File.join MLGREP_HOME, '..', "README.md"

  def self.usage
    File.open(README).readlines.select { |line| line !~ /^`/ }.each { |line|
      puts line.gsub(/`|^#+ |^--/, '').sub('Command flag  ', 'Command flag')
    }
    throw :exit
  end

  def self.short_usage(msg)
    $stderr << msg << "\n\n" <<
      # Extract usage information (synopsis) from README file.
      IO.read(README)[%r"Usage.*?(?=^\S)"m] << "\n"
    throw :exit
  end
end

def hashbang_matches(normalized_args, dir)
  interpreters = LANGUAGES.merge(
    # TODO: Find out what -S means in run-time instead of hard-coding.
    '-S' => { hashbang: %r'perl|python|ruby|/(ba)?sh'i }
  )
  matches = []
  suffixless = Dir[File.join(dir, '*')] - Dir[File.join(dir, '*.*')]
  suffixless.each { |s|
    File.open_with_error_handling(s) { |f|
      if not f.eof? and f.readline.force_encoding('ASCII-8BIT') =~ /^#!.*/
        line1 = $&
        normalized_args.each { |arg|
          lang = interpreters[arg]
          matches << s if lang and line1 =~ lang[:hashbang]
        }
      end
    }
  }
  matches
end

class File
  def self.open_with_error_handling(name)
    if file? name and readable? name and not symlink? name and name !~ /~$/
      begin
        open(name) { |f| yield f }
      rescue EOFError, Errno::EACCES, Errno::ENXIO => e
        $stdout.puts "mlgrep: #{e}"
      end
    end
  end
end

class String
  PROPER_NAME = {
    # These are mappings from encoding names that appear in MRI ruby source
    # code to their real names.
    'NIL' => 'ASCII-8BIT',
    'EUC' => 'EUC-JP',
    'UTF' => 'UTF-8'
  }

  RE = %r"^(#|/\*|//) (-\*- )?\b(en)?coding: ([\w-]+)"

  def multiline_grep(file_name, do_strip, re, flags, &block)
    begin
      if self =~ RE
        encoding = $4
      end
    rescue ArgumentError => e
      unless flags[:ignore_errors]
        $stderr.puts "mlgrep: #{e} in #{file_name}"
        return
      end
    end

    pre_process_text(flags, file_name)
    do_search(encoding, file_name, do_strip, re, flags, &block)
  end

  def pre_process_text(flags, file_name)
    if flags[:no_comments]
      replace case file_name
              when /\.xml$/i
                without_xml_comments
              when /\.(properties|cfg|rb|sh|pm|pl|py|cmake|mak)$/,
                /CMakeLists.txt/
                without_script_comments
              else
                match = self =~ /\A#[!\s]/m rescue nil
                if match
                  without_script_comments
                else
                  without_cpp_comments
                end
              end
    end
    if flags[:no_strings]
      if file_name =~ /\.py$/ || self =~ /\A#.*ython/
        replace without_python_strings
      else
        replace without_cpp_strings
      end
    end
  end

  def do_search(encoding, file_name, do_strip, re, flags)
    pos = 0
    loop {
      begin
        if encoding
          self[pos..-1].force_encoding PROPER_NAME[encoding.upcase] || encoding
          break unless self[pos..-1].valid_encoding?
        end
        relpos = self[pos..-1] =~ re or break
      rescue ArgumentError => e
        unless flags[:ignore_errors]
          $stderr.puts "mlgrep: Warning: #{e} in #{file_name}"
        end
        break
      end
      line  = self[0..pos + relpos].count("\n") + 1
      match = if flags[:only_match]
                # rubocop:disable VariableInterpolation
                "#$1 #$2 #$3 #$4 #$5 #$6 #$7 #$8 #$9".strip || $&
                # rubocop:enable VariableInterpolation
              else
                $&
              end
      if $&.empty?
        pos += relpos + 1 # avoid infinite loop
        break if pos >= length
      else
        match_length = $&.length
        match.gsub!(/\s+/, ' ') if do_strip == :strip
        q = flags[:quiet]
        match[q...-q] = ' ... ' if q and match.size > 2 * q + 5
        yield line, match
        pos += relpos + match_length
      end
    }
  end

  def realpath
    Pathname.new(self).realpath.to_s
  end

  # Dummy implementations of string encoding methods for ruby 1.8.
  unless "".respond_to? :force_encoding
    def force_encoding(name) self end
    def valid_encoding?() true end
  end
end
