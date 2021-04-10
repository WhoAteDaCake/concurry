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
    config.commands.each do | command_name, cmd |
      chdir = cmd.chdir
      chdir = case chdir
        in Nil
          Dir.current
        in String
          Path[chdir].expand
      end
      chdir = chdir.to_s
     
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
      STDOUT.printf("[%s] Starting\n", command_name)
      out_read, out_write = IO.pipe
      err_read, err_write = IO.pipe
      proc = Process.new(
        cmd.command,
        args,
        chdir: chdir,
        input: Process::Redirect::Close,
        output: out_write,
        error: err_write
      )

      # STDOUT
      spawn do
        while !out_read.closed?
          STDOUT.printf("[%s] %s", command_name, out_read.gets(chomp: false))
        end
      end

      # STDERR
      spawn do
        while !err_read.closed?
          STDERR.printf("[%s] %s", command_name, err_read.gets(chomp: false))
        end
      end
    end
    sleep
  end
end

Commander.run(cli, ARGV)