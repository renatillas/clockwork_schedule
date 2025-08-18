# clockwork_schedule

[![Package Version](https://img.shields.io/hexpm/v/clockwork_schedule)](https://hex.pm/packages/clockwork_schedule)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/clockwork_schedule/)

A scheduling extension for the [Clockwork](https://github.com/renatillas/clockwork) library, providing a way to define and manage recurring tasks with built-in OTP supervision support.

## Installation

```sh
gleam add clockwork_schedule
```

## Overview

`clockwork_schedule` builds on top of the Clockwork cron library to provide a complete scheduling solution for Gleam applications. It handles:

- **Automatic task execution** based on cron expressions
- **OTP supervision** for fault-tolerant scheduled tasks
- **Time zone support** with configurable UTC offsets
- **Built-in logging** for monitoring scheduled job execution
- **Graceful shutdown** with proper cleanup

## Usage

### Basic Example

```gleam
import clockwork
import clockwork_schedule as schedule
import gleam/io

pub fn main() {
  // Create a cron expression for every 5 minutes
  let assert Ok(cron) = clockwork.from_string("*/5 * * * *")
  
  // Define the job to run
  let job = fn() { io.println("Task executed!") }
  
  // Create and start the scheduler
  let scheduler = schedule.new("my_task", cron, job)
  let assert Ok(schedule) = schedule.start(scheduler)
  
  // The job will now run every 5 minutes
  // To stop the scheduler:
  schedule.stop(schedule)
}
```

### Supervised Scheduler

For production applications, use supervised schedulers that integrate with your OTP supervision tree:

```gleam
import clockwork
import clockwork_schedule as schedule
import gleam/erlang/process
import gleam/otp/static_supervisor as supervisor
import gleam/io

pub fn main() {
  // Create a cron expression
  let assert Ok(cron) = clockwork.from_string("0 */2 * * *")  // Every 2 hours
  
  // Create a scheduler with logging enabled
  let scheduler = 
    schedule.new("hourly_report", cron, fn() {
      io.println("Generating hourly report...")
      // Your business logic here
    })
    |> schedule.with_logging()
  
  // Set up supervision
  let schedule_receiver = process.new_subject()
  let schedule_child_spec = schedule.supervised(scheduler, schedule_receiver)
  
  // Start the supervisor
  let assert Ok(_supervisor) =
    supervisor.new()
    |> supervisor.add(schedule_child_spec)
    |> supervisor.start
  
  // Retrieve the schedule handle
  let assert Ok(schedule) = process.receive(schedule_receiver, 1000)
  
  // The scheduler is now running under supervision
  process.sleep_forever()
}
```

### Time Zone Support

Configure schedulers to run in specific time zones using UTC offsets:

```gleam
import clockwork_schedule as schedule
import gleam/time/duration

// Create a scheduler that runs in UTC+9 (Tokyo time)
let tokyo_offset = duration.from_hours(9)

let scheduler = 
  schedule.new("tokyo_task", cron, job)
  |> schedule.with_time_offset(tokyo_offset)
  |> schedule.with_logging()
```

## API Reference

### Types

- `Schedule` - A handle to a running scheduler that can be used to stop it
- `Scheduler` - Configuration for a scheduled task (opaque type)
- `Message` - Internal message types: `Run` and `Stop`

### Functions

#### `new(id: String, cron: clockwork.Cron, job: fn() -> Nil) -> Scheduler`
Creates a new scheduler configuration with the given ID, cron expression, and job function.

#### `with_logging(scheduler: Scheduler) -> Scheduler`
Enables logging for the scheduler, which will log when jobs are started and stopped.

#### `with_time_offset(scheduler: Scheduler, offset: duration.Duration) -> Scheduler`
Sets a UTC offset for the scheduler, useful for running jobs in specific time zones.

#### `start(scheduler: Scheduler) -> Result(Schedule, actor.StartError)`
Starts an unsupervised scheduler. Returns a `Schedule` handle for stopping the scheduler.

#### `supervised(scheduler: Scheduler, schedule_receiver: process.Subject(Schedule)) -> supervision.ChildSpec`
Creates a child specification for running the scheduler under OTP supervision. The schedule handle will be sent to the provided subject once started.

#### `stop(schedule: Schedule) -> Nil`
Gracefully stops a running scheduler.

## Features

### Automatic Scheduling
The library automatically calculates the next occurrence of your cron expression and schedules the job execution accordingly. After each execution, it immediately schedules the next occurrence.

### Fault Tolerance
When used with OTP supervision, schedulers can automatically restart if they crash, ensuring your scheduled tasks remain reliable.

### Concurrent Execution
Each scheduled job runs in its own process, preventing long-running tasks from blocking the scheduler.

### Logging
With logging enabled, the scheduler will output:
- When a job is executed (with timestamp)
- When a scheduler is stopped

## Examples

### Daily Database Cleanup
```gleam
let assert Ok(cron) = clockwork.from_string("0 3 * * *")  // 3 AM daily

let scheduler = 
  schedule.new("db_cleanup", cron, fn() {
    database.cleanup_old_records()
    database.vacuum()
  })
  |> schedule.with_logging()
```

### Periodic Health Checks
```gleam
let assert Ok(cron) = clockwork.from_string("*/10 * * * *")  // Every 10 minutes

let scheduler = 
  schedule.new("health_check", cron, fn() {
    case health.check_services() {
      Ok(_) -> Nil
      Error(service) -> alert.send_notification(service)
    }
  })
```

### Weekly Reports
```gleam
let assert Ok(cron) = clockwork.from_string("0 9 * * 1")  // Mondays at 9 AM

let scheduler = 
  schedule.new("weekly_report", cron, fn() {
    let report = analytics.generate_weekly_report()
    email.send_report(report)
  })
  |> schedule.with_logging()
```

## Dependencies

- `gleam_stdlib` - Core Gleam functionality
- `gleam_time` - Time and duration handling
- `gleam_otp` - OTP actor and supervision support
- `gleam_erlang` - Process management
- `logging` - Structured logging
- `clockwork` - Cron expression parsing and calculation

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Related Projects

- [clockwork](https://github.com/renatillas/clockwork) - The underlying cron expression library
