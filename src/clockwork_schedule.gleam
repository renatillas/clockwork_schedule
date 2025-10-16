/// # clockwork_schedule
/// 
/// A scheduling extension for the Clockwork library that provides a way to define
/// and manage recurring tasks with built-in OTP supervision support.
/// 
/// This module allows you to:
/// - Schedule tasks using cron expressions
/// - Run tasks under OTP supervision for fault tolerance
/// - Configure time zones with UTC offsets
/// - Enable logging for monitoring job execution
/// - Gracefully start and stop scheduled tasks
/// 
/// ## Basic Usage
///
/// ```gleam
/// import clockwork
/// import clockwork_schedule
/// import gleam/erlang/process
///
/// pub fn main() {
///   let assert Ok(cron) = clockwork.from_string("*/5 * * * *")
///   let scheduler = clockwork_schedule.new("my_task", cron, fn() { io.println("Hello!") })
///   let name = process.new_name("my_task")
///   let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)
///   // Task runs every 5 minutes until stopped
///   clockwork_schedule.stop(name)
/// }
/// ```
import clockwork
import gleam/erlang/process
import gleam/float
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import logging

/// Internal message types used by the scheduler actor.
/// 
/// - `Run`: Triggers the execution of the scheduled job
/// - `Stop`: Gracefully stops the scheduler
pub type Message {
  Run
  Stop
}

type State {
  State(
    id: String,
    self: process.Subject(Message),
    cron: clockwork.Cron,
    job: fn() -> Nil,
    offset: duration.Duration,
  )
}

/// Configuration for a scheduled task.
/// 
/// A `Scheduler` contains all the information needed to run a recurring task:
/// - An identifier for logging and debugging
/// - A cron expression defining when to run
/// - The job function to execute
/// - Optional logging configuration
/// - Optional time zone offset
/// 
/// Use the builder pattern to configure schedulers:
/// 
/// ```gleam
/// import gleam/erlang/process
///
/// let scheduler =
///   clockwork_schedule.new("backup", cron, backup_fn)
///   |> clockwork_schedule.with_logging()
///   |> clockwork_schedule.with_time_offset(tokyo_offset)
///
/// let name = process.new_name("backup")
/// let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)
/// ```
pub opaque type Scheduler {
  Scheduler(
    id: String,
    cron: clockwork.Cron,
    job: fn() -> Nil,
    with_logging: Bool,
    offset: duration.Duration,
  )
}

/// Creates a new scheduler configuration.
/// 
/// ## Parameters
/// 
/// - `id`: A unique identifier for this scheduler (used in logging)
/// - `cron`: A cron expression defining when the job should run
/// - `job`: The function to execute on each scheduled occurrence
/// 
/// ## Example
/// 
/// ```gleam
/// import clockwork
/// 
/// let assert Ok(cron) = clockwork.from_string("0 */2 * * *")  // Every 2 hours
/// let scheduler = clockwork_schedule.new("data_sync", cron, fn() {
///   database.sync_remote_data()
/// })
/// ```
pub fn new(id: String, cron: clockwork.Cron, job: fn() -> Nil) -> Scheduler {
  Scheduler(id, cron, job, False, calendar.utc_offset)
}

/// Enables logging for the scheduler.
/// 
/// When logging is enabled, the scheduler will log:
/// - When a job starts executing (with timestamp)
/// - When the scheduler is stopped
/// 
/// Logging uses the `logging` library and outputs at the `Info` level.
/// 
/// ## Example
/// 
/// ```gleam
/// let scheduler = 
///   clockwork_schedule.new("cleanup", cron, cleanup_fn)
///   |> clockwork_schedule.with_logging()  // Enable logging
/// ```
pub fn with_logging(scheduler: Scheduler) -> Scheduler {
  Scheduler(scheduler.id, scheduler.cron, scheduler.job, True, scheduler.offset)
}

/// Sets a time zone offset for the scheduler.
/// 
/// By default, schedulers use the system's UTC offset. Use this function
/// to run scheduled tasks in a specific time zone.
/// 
/// ## Parameters
/// 
/// - `scheduler`: The scheduler to configure
/// - `offset`: The UTC offset as a Duration (positive for east, negative for west)
/// 
/// ## Example
///
/// ```gleam
/// import gleam/erlang/process
/// import gleam/time/duration
///
/// // Configure for UTC+9 (Tokyo)
/// let tokyo_offset = duration.from_hours(9)
///
/// let tokyo_scheduler =
///   clockwork_schedule.new("tokyo_job", cron, job_fn)
///   |> clockwork_schedule.with_time_offset(tokyo_offset)
///
/// let tokyo_name = process.new_name("tokyo_job")
/// let assert Ok(_subject) = clockwork_schedule.start(tokyo_scheduler, tokyo_name)
///
/// // Configure for UTC-5 (New York)
/// let ny_offset = duration.from_hours(-5)
///
/// let ny_scheduler =
///   clockwork_schedule.new("ny_job", cron, job_fn)
///   |> clockwork_schedule.with_time_offset(ny_offset)
///
/// let ny_name = process.new_name("ny_job")
/// let assert Ok(_subject) = clockwork_schedule.start(ny_scheduler, ny_name)
/// ```
pub fn with_time_offset(
  scheduler: Scheduler,
  offset: duration.Duration,
) -> Scheduler {
  Scheduler(
    scheduler.id,
    scheduler.cron,
    scheduler.job,
    scheduler.with_logging,
    offset,
  )
}

fn start_actor(
  scheduler: Scheduler,
  name: process.Name(Message),
) -> actor.StartResult(process.Subject(Message)) {
  case scheduler.with_logging {
    True -> logging.configure()
    False -> Nil
  }

  actor.new_with_initialiser(100, fn(self) {
    let state =
      State(
        id: scheduler.id,
        self:,
        cron: scheduler.cron,
        job: scheduler.job,
        offset: scheduler.offset,
      )

    let selector =
      process.new_selector()
      |> process.select(self)

    enqueue_job(scheduler.cron, state)

    actor.initialised(state)
    |> actor.selecting(selector)
    |> actor.returning(self)
    |> Ok
  })
  |> actor.on_message(loop)
  |> actor.named(name)
  |> actor.start
}

/// Starts an unsupervised scheduler.
///
/// This function starts a scheduler as a standalone actor that will run
/// according to its cron expression. For production use, prefer `supervised`
/// to run the scheduler under OTP supervision for better fault tolerance.
///
/// ## Parameters
///
/// - `scheduler`: The scheduler configuration to start
/// - `name`: A unique name for the scheduler process
///
/// ## Returns
///
/// - `Ok(Subject(Message))`: A subject to send messages to the scheduler
/// - `Error(actor.StartError)`: If the scheduler fails to start
///
/// ## Example
///
/// ```gleam
/// import clockwork
/// import clockwork_schedule
/// import gleam/erlang/process
///
/// pub fn main() {
///   let assert Ok(cron) = clockwork.from_string("*/30 * * * *")  // Every 30 minutes
///
///   let scheduler =
///     clockwork_schedule.new("metrics", cron, fn() {
///       metrics.collect_and_report()
///     })
///     |> clockwork_schedule.with_logging()
///
///   let name = process.new_name("metrics")
///   let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)
///
///   // The scheduler is now running
///   // Stop it when done:
///   clockwork_schedule.stop(name)
/// }
/// ```
///
/// ## Note
///
/// The scheduler will continue running until explicitly stopped with `stop`
/// or until the process crashes. For automatic restart on failure, use
/// `supervised` instead.
pub fn start(
  scheduler: Scheduler,
  name: process.Name(Message),
) -> actor.StartResult(process.Subject(Message)) {
  start_actor(scheduler, name)
}

/// Creates a child specification for running the scheduler under OTP supervision.
///
/// This is the recommended way to run schedulers in production. The scheduler
/// will be automatically restarted if it crashes, ensuring your scheduled
/// tasks remain reliable.
///
/// ## Parameters
///
/// - `scheduler`: The scheduler configuration
/// - `name`: A unique name for the scheduler process
///
/// ## Returns
///
/// A `supervision.ChildSpec` that can be added to your supervision tree.
///
/// ## Example
///
/// ```gleam
/// import clockwork
/// import clockwork_schedule
/// import gleam/erlang/process
/// import gleam/otp/static_supervisor as supervisor
///
/// pub fn main() {
///   let assert Ok(cron) = clockwork.from_string("0 * * * *")  // Every hour
///
///   let scheduler =
///     clockwork_schedule.new("hourly_task", cron, fn() {
///       perform_hourly_maintenance()
///     })
///     |> clockwork_schedule.with_logging()
///
///   // Create a unique name for the scheduler
///   let name = process.new_name("hourly_task")
///
///   // Create the child spec
///   let schedule_child_spec =
///     clockwork_schedule.supervised(scheduler, name)
///
///   // Add to supervision tree
///   let assert Ok(_sup) =
///     supervisor.new()
///     |> supervisor.add(schedule_child_spec)
///     |> supervisor.start()
///
///   // The scheduler is now running under supervision
///   // Control it using the name:
///   // clockwork_schedule.stop(name)
///   process.sleep_forever()
/// }
/// ```
///
/// ## Fault Tolerance
///
/// If the scheduler crashes, the supervisor will automatically restart it.
/// The new instance will recalculate the next occurrence and continue
/// scheduling jobs as expected.
pub fn supervised(scheduler: Scheduler, name: process.Name(Message)) {
  supervision.worker(fn() {
    use started <- result.try(start_actor(scheduler, name))
    Ok(started)
  })
}

/// Gracefully stops a running scheduler.
///
/// Sends a stop message to the scheduler, which will:
/// 1. Cancel any pending job executions
/// 2. Log a stop message (if logging is enabled)
/// 3. Terminate the scheduler actor
///
/// ## Parameters
///
/// - `name`: The name of the scheduler process to stop
///
/// ## Example
///
/// ```gleam
/// import gleam/erlang/process
///
/// let name = process.new_name("my_scheduler")
/// let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)
///
/// // Run for some time...
/// process.sleep(60_000)  // 1 minute
///
/// // Gracefully stop
/// clockwork_schedule.stop(name)
/// ```
///
/// ## Note
///
/// After calling `stop`, the scheduler will terminate. To restart scheduling,
/// create and start a new scheduler with a new name.
pub fn stop(name: process.Name(Message)) {
  process.named_subject(name)
  |> process.send(Stop)
}

fn loop(state: State, message: Message) {
  case message {
    Run -> {
      logging.log(
        logging.Info,
        "[CLOCKWORK] Running job: "
          <> state.id
          <> " at "
          <> timestamp.system_time()
        |> timestamp.add(state.offset)
        |> timestamp.to_unix_seconds
        |> float.to_string(),
      )
      process.spawn(state.job)
      enqueue_job(state.cron, state)
      actor.continue(state)
    }
    Stop -> {
      logging.log(logging.Info, "[CLOCKWORK] Stopping job: " <> state.id)
      actor.stop()
    }
  }
}

fn enqueue_job(cron, state: State) {
  let now = timestamp.system_time()
  let next_occurrence =
    clockwork.next_occurrence(cron, now, state.offset)
    |> timestamp.difference(now, _)
    |> duration.to_seconds_and_nanoseconds
    |> fn(tuple) {
      let #(seconds, nanoseconds) = tuple
      let milliseconds = seconds * 1000 + nanoseconds / 1_000_000
      case milliseconds < 0 {
        True -> 100
        False -> milliseconds
      }
    }

  process.send_after(state.self, next_occurrence, Run)
}
