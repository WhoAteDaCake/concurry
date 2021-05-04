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
    processes = Array(Process).new
    shutdown_channel = Channel(Nil).new

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
      # Save for later checking
      processes << proc

      # STDOUT
      # Assumes stdout is closed at the same time as stderr
      spawn do
        until out_read.closed?
          line = out_read.gets(chomp: false)
          if line.nil?
            break
          end
          STDOUT.printf("[%s] %s", command_name, line)
        end
      end

      # STDERR
      spawn do
        until err_read.closed?
          line = err_read.gets(chomp: false)
          if line.nil? 
            break
          end
          STDERR.printf("[%s] %s", command_name, line)
        end
      end

      spawn do
        while !proc.terminated?
          sleep 1
        end
        STDERR.printf("[%s] Terminated\n", command_name)
        shutdown_channel.send(nil)
      end

    end

    # If any of the programs shutdown, we terminate the rest
    shutdown_channel.receive
    puts "Received shutdown, terminating"

    processes.each do | p |
      if p.terminated?
        status = p.wait
        processes.each do | p2 |
          if p2.pid != p.pid
            p2.terminate
            p2.wait
          end
        end
        exit(status.exit_code)
      end
    end
  end
end

Commander.run(cli, ARGV)