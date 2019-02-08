# Short script to parse a TOML configurations file and write the corresponding
# YAML file.

require "toml-rb"
require "yaml"

def die(msg)
    abort("ERROR: #{msg}")
end

# Parse script arguments to get file list to convert.
ARGV.each do |tomlfile|
    if tomlfile[/.*\.([^\.]*)/,1] != "toml"
        die "File #{tomlfile} has not a \".toml\" extension."
    end
    if ! File.file?(tomlfile)
        die "File #{tomlfile} not found."
    end
    # Read TOML configuration file.
    conf = TomlRB.load_file(tomlfile) ||
        die("Loading configuration file #{tomlfile} failed, aborting.")
    # Generate output file name by changing extension to ".yaml".
    yamlfile = tomlfile.gsub( /toml/, 'yaml' )
    # Write output YAML configuration file.
    File.open(yamlfile,"w") do |convfile|
        convfile.write conf.to_yaml
    end

end


