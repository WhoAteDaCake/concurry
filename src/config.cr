require "yaml"

ENV_VAR_RE = /\$(([A-Z]|_)+)/

class Config
  include YAML::Serializable

  class Command 
    include YAML::Serializable

    class CheckedArgument
      include YAML::Serializable

      property when : String
      property show : String | Array(String)
    end

    property chdir : String ?
    property command : String
    property arguments : Array(CheckedArgument | Array(String) | String)
  end

  property defaults : Hash(String, String)
  property commands : Hash(String, Command)

  def get_env(var, env)
    env.fetch(var, @defaults[var]?)
  end

  def fill_arg(argument, env)
    var = ENV_VAR_RE.match(argument).try &.[1]
    if var.nil?
      argument
    else
      value = get_env(var, env)
      if value.nil?
        puts "Missing env variable: [#{var}]"
        Process.exit
      else
        argument.gsub("$" + var, value)
      end
    end
  end

  def parse(arg, env)
    if arg.is_a?(String)
      fill_arg(arg.as(String), env)
    elsif arg.is_a?(Array(String))
      arg.as(Array(String)).map { | a | fill_arg(a, env) }
    else
      spec = arg.as(Command::CheckedArgument)
      # Remove $
      if get_env(spec.when.delete_at(0), env).nil?
        nil
      else
        parse(spec.show, env)
      end
    end
  end
end