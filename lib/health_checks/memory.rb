module HealthChecks
  MAX_MEMORY_USAGE = 75

  module_function

  def memory
    total_memory = File.read('/sys/fs/cgroup/memory/memory.limit_in_bytes').to_i
    used_memory = File.read('/sys/fs/cgroup/memory/memory.usage_in_bytes').to_i
    usage = used_memory * 100 / total_memory

    raise "Using #{usage}% of available memory" if usage > MAX_MEMORY_USAGE

    usage
  end
end
