require "commander"
require "./config"

cli = Commander::Command.new do |cmd|
  cmd.use  = "con-curry"
  cmd.long = "con-curry: Program used to start concurrent processes"

  cmd.flags.add do |flag|
    flag.name        = "config"
    flag.short       = "-c"
    flag.long        = "--config"
    flag.description = "YAML config file path"
    flag.default     = "none"
    flag.persistent  = true
  end

  cmd.run do |options, arguments|
    cfg_path = options.string["config"]
    if cfg_path == "none"
      puts "Please specify config file via --config flag"
      Process.exit
    end

    config = File.open(Path[cfg_path].expand) do |file|
      Config.from_yaml(file)
    end

    env = ENV
    # puts config.fill_arg("test: $DAPR_HTTP_PORT", ENV)
    config.commands.each do | k, cmd |
      args = cmd.arguments.reduce(Array(String).new) do | items, arg |
        result = config.parse(arg, env)
        case result
          in Nil
            items
          in String
            items << result
            items
          in Array(String)
            items + result
        end
      end
      puts args
    end
  end

end

Commander.run(cli, ARGV)