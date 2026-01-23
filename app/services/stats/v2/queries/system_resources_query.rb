# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for system resource metrics (CPU, Memory, Disk)
      class SystemResourcesQuery
        # Get all system resource metrics
        # @return [Hash] hash with CPU, memory, and disk metrics (values may be nil)
        def self.call
          new.call
        end

        def call
          {
            cpu_util: cpu_util,
            cpu_cores: cpu_cores,
            memory_util_percent: memory_util_percent,
            total_memory_gb: total_memory_gb,
            disk_util_percent: disk_util_percent,
            total_disk_gb: total_disk_gb
          }
        end

        private

        def os
          @os ||= RbConfig::CONFIG["host_os"]
        end

        def macos?
          os =~ /darwin/i
        end

        def linux?
          os =~ /linux/i
        end

        def cpu_util
          if macos?
            `top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%'`.to_f
          elsif linux?
            calculate_linux_cpu_util
          end
        rescue StandardError => e
          Rails.logger.error "Error getting CPU util: #{e.message}"
          nil
        end

        def calculate_linux_cpu_util
          cpu_info = `cat /proc/stat | grep '^cpu '`.split
          return nil unless cpu_info.size >= 5

          user = cpu_info[1].to_i
          nice = cpu_info[2].to_i
          system = cpu_info[3].to_i
          idle = cpu_info[4].to_i
          iowait = cpu_info[5].to_i
          irq = cpu_info[6].to_i
          softirq = cpu_info[7].to_i
          steal = cpu_info[8].to_i if cpu_info.size > 8
          steal ||= 0

          total = user + nice + system + idle + iowait + irq + softirq + steal
          used = total - idle - iowait
          (used.to_f / total * 100).round(1)
        end

        def cpu_cores
          if macos?
            `sysctl -n hw.ncpu`.to_i
          elsif linux?
            `nproc`.to_i
          end
        rescue StandardError => e
          Rails.logger.error "Error getting CPU cores: #{e.message}"
          nil
        end

        def memory_util_percent
          if macos?
            calculate_macos_memory_util
          elsif linux?
            calculate_linux_memory_util
          end
        rescue StandardError => e
          Rails.logger.error "Error getting memory util: #{e.message}"
          nil
        end

        def calculate_macos_memory_util
          vm_stat = `vm_stat`
          free_pages = vm_stat.match(/Pages free:\s+(\d+)/)[1].to_i
          inactive_pages = vm_stat.match(/Pages inactive:\s+(\d+)/)[1].to_i
          speculative_pages = vm_stat.match(/Pages speculative:\s+(\d+)/)[1].to_i

          total_memory = `sysctl -n hw.memsize`.to_i
          page_size = 4096
          available_memory = (free_pages + inactive_pages + speculative_pages) * page_size
          free_memory_percent = (available_memory.to_f / total_memory * 100).round(1)
          100 - free_memory_percent
        end

        def calculate_linux_memory_util
          mem_info = `cat /proc/meminfo`
          total_kb = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
          free_kb = mem_info.match(/MemFree:\s+(\d+)/)[1].to_i
          buffers_kb = mem_info.match(/Buffers:\s+(\d+)/)[1].to_i
          cached_kb = mem_info.match(/Cached:\s+(\d+)/)[1].to_i

          available_kb = free_kb + buffers_kb + cached_kb
          free_memory_percent = (available_kb.to_f / total_kb * 100).round(1)
          100 - free_memory_percent
        end

        def total_memory_gb
          if macos?
            total_memory = `sysctl -n hw.memsize`.to_i
            (total_memory / 1024.0 / 1024.0).round(1)
          elsif linux?
            mem_info = `cat /proc/meminfo`
            total_kb = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
            (total_kb / 1024.0 / 1024.0).round(1)
          end
        rescue StandardError => e
          Rails.logger.error "Error getting total memory: #{e.message}"
          nil
        end

        def disk_util_percent
          df_output = `df -h /`
          df_lines = df_output.split("\n")
          return nil unless df_lines.length > 1

          disk_info = df_lines[1].split
          if macos?
            disk_info[4].to_i
          elsif linux?
            disk_info[4].gsub("%", "").to_i
          end
        rescue StandardError => e
          Rails.logger.error "Error getting disk util: #{e.message}"
          nil
        end

        def total_disk_gb
          df_output = `df -h /`
          df_lines = df_output.split("\n")
          return nil unless df_lines.length > 1

          disk_info = df_lines[1].split
          disk_info[1].gsub(/[^\d.]/, "").to_f
        rescue StandardError => e
          Rails.logger.error "Error getting total disk: #{e.message}"
          nil
        end
      end
    end
  end
end
