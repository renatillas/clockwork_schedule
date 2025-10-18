# clockwork_schedule

[![Package Version](https://img.shields.io/hexpm/v/clockwork_schedule)](https://hex.pm/packages/clockwork_schedule)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/clockwork_schedule/)

A robust scheduling extension for the [Clockwork](https://hex.pm/packages/clockwork) library that provides a clean, type-safe way to define and manage recurring tasks with built-in OTP supervision support in Gleam applications.

## Installation

```sh
gleam add clockwork_schedule@2
```

## Quick Start

```gleam
import clockwork
import clockwork_schedule
import gleam/erlang/process
import gleam/io

pub fn main() {
  // Create a cron expression (runs every 5 minutes)
  let assert Ok(cron) = clockwork.from_string("*/5 * * * *")

  // Define your job
  let job = fn() { io.println("Task executed!") }

  // Create a unique name for the scheduler
  let name = process.new_name("my_task")

  // Create and start the scheduler
  let scheduler = clockwork_schedule.new("my_task", cron, job)
  let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)

  // The task will run every 5 minutes until stopped
  // Stop when done
  clockwork_schedule.stop(name)
}
```

## Usage Examples

### Basic Scheduled Task

```gleam
import clockwork
import clockwork_schedule
import gleam/erlang/process

pub fn hourly_cleanup() {
  let assert Ok(cron) = clockwork.from_string("0 * * * *")  // Every hour

  let scheduler =
    clockwork_schedule.new("cleanup", cron, fn() {
      // Your cleanup logic here
      delete_old_temp_files()
      compress_logs()
    })

  let name = process.new_name("cleanup")
  let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)
  // The scheduler is now running, identified by its name
}
```

### With Logging Enabled

```gleam
import gleam/erlang/process

let scheduler =
  clockwork_schedule.new("data_sync", cron, sync_function)
  |> clockwork_schedule.with_logging()  // Enable execution logging

let name = process.new_name("data_sync")
let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)

// Logs will show:
// [CLOCKWORK] Running job: data_sync at 1706025600.0
// [CLOCKWORK] Stopping job: data_sync
```

### Time Zone Configuration

```gleam
import gleam/erlang/process
import gleam/time/duration

// Configure for UTC+9 (Tokyo)
let tokyo_offset = duration.from_hours(9)

let tokyo_scheduler =
  clockwork_schedule.new("tokyo_report", cron, generate_report)
  |> clockwork_schedule.with_time_offset(tokyo_offset)

let tokyo_name = process.new_name("tokyo_report")
let assert Ok(_tokyo_subject) = clockwork_schedule.start(tokyo_scheduler, tokyo_name)

// Configure for UTC-5 (New York)
let ny_offset = duration.from_hours(-5)

let ny_scheduler =
  clockwork_schedule.new("ny_report", cron, generate_report)
  |> clockwork_schedule.with_time_offset(ny_offset)

let ny_name = process.new_name("ny_report")
let assert Ok(_ny_subject) = clockwork_schedule.start(ny_scheduler, ny_name)
```

### Supervised Scheduling (Recommended for Production)

```gleam
import clockwork
import clockwork_schedule
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor

pub fn main() {
  let assert Ok(cron) = clockwork.from_string("0 0 * * *")  // Daily at midnight

  let scheduler =
    clockwork_schedule.new("daily_backup", cron, backup_database)
    |> clockwork_schedule.with_logging()

  // Create a unique name for the scheduler
  let name = process.new_name("daily_backup")

  // Create the child specification
  let child_spec =
    clockwork_schedule.supervised(scheduler, name)

  // Add to supervision tree
  let assert Ok(_sup) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(child_spec)
    |> supervisor.start()

  // The scheduler is now running under supervision
  // It will automatically restart if it crashes
  // You can control it using the name:
  // clockwork_schedule.stop(name)
}
```

### Multiple Concurrent Schedulers

```gleam
import gleam/erlang/process

pub fn start_all_schedulers() {
  // Metrics collection every 5 minutes
  let assert Ok(metrics_cron) = clockwork.from_string("*/5 * * * *")
  let metrics_scheduler =
    clockwork_schedule.new("metrics", metrics_cron, collect_metrics)

  // Database backup every day at 2 AM
  let assert Ok(backup_cron) = clockwork.from_string("0 2 * * *")
  let backup_scheduler =
    clockwork_schedule.new("backup", backup_cron, backup_database)

  // Cache cleanup every hour
  let assert Ok(cache_cron) = clockwork.from_string("0 * * * *")
  let cache_scheduler =
    clockwork_schedule.new("cache", cache_cron, clear_cache)

  // Create names for all schedulers
  let metrics_name = process.new_name("metrics")
  let backup_name = process.new_name("backup")
  let cache_name = process.new_name("cache")

  // Start all schedulers
  let assert Ok(_metrics_subject) = clockwork_schedule.start(metrics_scheduler, metrics_name)
  let assert Ok(_backup_subject) = clockwork_schedule.start(backup_scheduler, backup_name)
  let assert Ok(_cache_subject) = clockwork_schedule.start(cache_scheduler, cache_name)

  // All three schedulers now run independently
  // Control them using their names:
  // clockwork_schedule.stop(metrics_name)
  // clockwork_schedule.stop(backup_name)
  // clockwork_schedule.stop(cache_name)
  #(metrics_name, backup_name, cache_name)
}
```

## Cron Expression Format

This library uses the [Clockwork](https://hex.pm/packages/clockwork) library for cron expression parsing:

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of the month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday)
│ │ │ │ │
│ │ │ │ │
* * * * *
```

### Common Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `* * * * *` | Every minute | Runs at :00, :01, :02, etc. |
| `*/5 * * * *` | Every 5 minutes | Runs at :00, :05, :10, etc. |
| `0 * * * *` | Every hour | Runs at the top of each hour |
| `0 0 * * *` | Daily at midnight | Runs at 00:00 |
| `0 0 * * 0` | Weekly on Sunday | Runs Sunday at midnight |
| `0 0 1 * *` | Monthly on the 1st | Runs on the 1st at midnight |
| `30 2 * * 1-5` | Weekdays at 2:30 AM | Mon-Fri at 02:30 |
| `0 */4 * * *` | Every 4 hours | Runs at 00:00, 04:00, 08:00, etc. |
| `0 9-17 * * 1-5` | Business hours | Mon-Fri, every hour 9 AM - 5 PM |

## Related Projects

- [Clockwork](https://hex.pm/packages/clockwork) - The underlying cron expression library
- [gleam_otp](https://hex.pm/packages/gleam_otp) - OTP abstractions for Gleam
- [logging](https://hex.pm/packages/logging) - Structured logging for Gleam

## Support

- [GitHub Issues](https://github.com/renatillas/clockwork_schedule/issues) - Bug reports and feature requests
- [Hex Documentation](https://hexdocs.pm/clockwork_schedule/) - API documentation
- [Gleam Discord](https://discord.gg/Fm8Pwmy) - Community support
