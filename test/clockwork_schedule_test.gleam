import clockwork
import clockwork_schedule
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/static_supervisor as supervisor
import gleam/time/duration
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn new_scheduler_test() {
  let assert Ok(cron) = clockwork.from_string("* * * * *")
  let job = fn() { io.println("test job") }
  let scheduler = clockwork_schedule.new("test_id", cron, job)

  should.be_ok(Ok(scheduler))
}

pub fn scheduler_with_logging_test() {
  let assert Ok(cron) = clockwork.from_string("* * * * *")
  let job = fn() { Nil }
  let scheduler =
    clockwork_schedule.new("test_id", cron, job)
    |> clockwork_schedule.with_logging()

  should.be_ok(Ok(scheduler))
}

pub fn scheduler_with_time_offset_test() {
  let assert Ok(cron) = clockwork.from_string("* * * * *")
  let job = fn() { Nil }
  let offset = duration.hours(5)
  let scheduler =
    clockwork_schedule.new("test_id", cron, job)
    |> clockwork_schedule.with_time_offset(offset)

  should.be_ok(Ok(scheduler))
}

pub fn start_and_stop_scheduler_test() {
  let name = process.new_name("name")

  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let job = fn() { Nil }

  let scheduler = clockwork_schedule.new("yearly_test", cron, job)
  let assert Ok(_) = clockwork_schedule.start(scheduler, name)

  clockwork_schedule.stop(name)
}

pub fn supervised_scheduler_test() {
  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let job = fn() { Nil }

  let scheduler =
    clockwork_schedule.new("supervised_test", cron, job)
    |> clockwork_schedule.with_logging()

  let name = process.new_name("name")
  let schedule_child_spec = clockwork_schedule.supervised(scheduler, name)

  let assert Ok(_sup) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(schedule_child_spec)
    |> supervisor.start()

  clockwork_schedule.stop(name)
}

pub fn immediate_job_test() {
  let result_subject = process.new_subject()
  let name = process.new_name("name")

  let job = fn() {
    let computation = int.sum([1, 2, 3, 4, 5])
    process.send(result_subject, computation)
  }

  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let scheduler = clockwork_schedule.new("scheduler", cron, job)

  let assert Ok(_) = clockwork_schedule.start(scheduler, name)

  let assert Ok(result) = process.receive(result_subject, 1000)

  clockwork_schedule.stop(name)
  assert result == 15
}

pub fn scheduler_with_different_offsets_test() {
  let name_1 = process.new_name("name-1")
  let name_2 = process.new_name("name-2")
  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let job = fn() { Nil }

  let tokyo_offset = duration.hours(9)
  let ny_offset = duration.hours(-5)

  let tokyo_scheduler =
    clockwork_schedule.new("tokyo_job", cron, job)
    |> clockwork_schedule.with_time_offset(tokyo_offset)

  let ny_scheduler =
    clockwork_schedule.new("ny_job", cron, job)
    |> clockwork_schedule.with_time_offset(ny_offset)

  let assert Ok(_) = clockwork_schedule.start(tokyo_scheduler, name_1)
  let assert Ok(_) = clockwork_schedule.start(ny_scheduler, name_2)

  clockwork_schedule.stop(name_1)
  clockwork_schedule.stop(name_2)
}
