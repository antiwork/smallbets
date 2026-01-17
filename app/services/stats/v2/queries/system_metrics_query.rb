# frozen_string_literal: true

module Stats
  module V2
    module Queries
      # Query object for calculating system-wide metrics
      class SystemMetricsQuery
        # Calculate all system metrics
        # @return [Hash] hash with all system metrics
        def self.call
          new.call
        end

        def call
          {
            total_users: total_users_count,
            online_users: online_users_count,
            total_messages: total_messages_count,
            total_threads: total_threads_count,
            total_boosts: total_boosts_count,
            total_posters: total_posters_count,
            database_size: database_size,
            cpu_util: cpu_util,
            cpu_cores: cpu_cores,
            memory_util_percent: memory_util_percent,
            total_memory_gb: total_memory_gb,
            disk_util_percent: disk_util_percent,
            total_disk_gb: total_disk_gb
          }
        end

        private

        def total_users_count
          User.where(active: true, suspended_at: nil).count
        end

        def online_users_count
          Membership.connected.select(:user_id).distinct.count
        end

        def total_messages_count
          Message.count
        end

        def total_threads_count
          Room.active
            .where(type: "Rooms::Thread")
            .joins(:messages)
            .where("messages.active = ?", true)
            .distinct
            .count
        end

        def total_boosts_count
          Boost.count
        end

        def total_posters_count
          User.active
            .joins(messages: :room)
            .where("rooms.type != ?", "Rooms::Direct")
            .where("messages.active = ?", true)
            .distinct
            .count
        end

        def database_size
          db_path = ActiveRecord::Base.connection_db_config.configuration_hash[:database]
          File.size(db_path)
        rescue StandardError
          0
        end

        def cpu_util
          os = RbConfig::CONFIG["host_os"]

          if os =~ /darwin/i
            `top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%'`.to_f
          elsif os =~ /linux/i
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
        rescue StandardError => e
          Rails.logger.error "Error getting CPU util: #{e.message}"
          nil
        end

        def cpu_cores
          os = RbConfig::CONFIG["host_os"]

          if os =~ /darwin/i
            `sysctl -n hw.ncpu`.to_i
          elsif os =~ /linux/i
            `nproc`.to_i
          end
        rescue StandardError => e
          Rails.logger.error "Error getting CPU cores: #{e.message}"
          nil
        end

        def memory_util_percent
          os = RbConfig::CONFIG["host_os"]

          if os =~ /darwin/i
            vm_stat = `vm_stat`
            free_pages = vm_stat.match(/Pages free:\s+(\d+)/)[1].to_i
            inactive_pages = vm_stat.match(/Pages inactive:\s+(\d+)/)[1].to_i
            speculative_pages = vm_stat.match(/Pages speculative:\s+(\d+)/)[1].to_i

            total_memory = `sysctl -n hw.memsize`.to_i
            page_size = 4096
            available_memory = (free_pages + inactive_pages + speculative_pages) * page_size
            free_memory_percent = (available_memory.to_f / total_memory * 100).round(1)
            100 - free_memory_percent
          elsif os =~ /linux/i
            mem_info = `cat /proc/meminfo`
            total_kb = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
            free_kb = mem_info.match(/MemFree:\s+(\d+)/)[1].to_i
            buffers_kb = mem_info.match(/Buffers:\s+(\d+)/)[1].to_i
            cached_kb = mem_info.match(/Cached:\s+(\d+)/)[1].to_i

            available_kb = free_kb + buffers_kb + cached_kb
            free_memory_percent = (available_kb.to_f / total_kb * 100).round(1)
            100 - free_memory_percent
          end
        rescue StandardError => e
          Rails.logger.error "Error getting memory util: #{e.message}"
          nil
        end

        def total_memory_gb
          os = RbConfig::CONFIG["host_os"]

          if os =~ /darwin/i
            total_memory = `sysctl -n hw.memsize`.to_i
            (total_memory / 1024.0 / 1024.0).round(1)
          elsif os =~ /linux/i
            mem_info = `cat /proc/meminfo`
            total_kb = mem_info.match(/MemTotal:\s+(\d+)/)[1].to_i
            (total_kb / 1024.0 / 1024.0).round(1)
          end
        rescue StandardError => e
          Rails.logger.error "Error getting total memory: #{e.message}"
          nil
        end

        def disk_util_percent
          os = RbConfig::CONFIG["host_os"]

          df_output = `df -h /`
          df_lines = df_output.split("\n")
          return nil unless df_lines.length > 1

          disk_info = df_lines[1].split
          if os =~ /darwin/i
            disk_info[4].to_i
          elsif os =~ /linux/i
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
