import clockwork
import clockwork_schedule
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
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
  let started_subject = process.new_subject()

  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let job = fn() { process.send(started_subject, "executed") }

  let scheduler = clockwork_schedule.new("yearly_test", cron, job)
  let assert Ok(schedule) = clockwork_schedule.start(scheduler)

  clockwork_schedule.stop(schedule)
}

pub fn supervised_scheduler_test() {
  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let job = fn() { Nil }

  let scheduler =
    clockwork_schedule.new("supervised_test", cron, job)
    |> clockwork_schedule.with_logging()

  let schedule_receiver = process.new_subject()
  let schedule_child_spec =
    clockwork_schedule.supervised(scheduler, schedule_receiver)

  let assert Ok(_sup) =
    supervisor.new(supervisor.OneForOne)
    |> supervisor.add(schedule_child_spec)
    |> supervisor.start()

  let assert Ok(schedule) = process.receive(schedule_receiver, 2000)

  clockwork_schedule.stop(schedule)
}

pub fn multiple_schedulers_test() {
  let assert Ok(cron1) = clockwork.from_string("0 0 1 1 *")
  let assert Ok(cron2) = clockwork.from_string("0 0 1 6 *")

  let job1 = fn() { Nil }
  let job2 = fn() { Nil }

  let scheduler1 = clockwork_schedule.new("scheduler1", cron1, job1)
  let scheduler2 = clockwork_schedule.new("scheduler2", cron2, job2)

  let assert Ok(schedule1) = clockwork_schedule.start(scheduler1)
  let assert Ok(schedule2) = clockwork_schedule.start(scheduler2)

  process.sleep(100)

  clockwork_schedule.stop(schedule1)
  clockwork_schedule.stop(schedule2)

  should.be_ok(Ok(schedule1))
  should.be_ok(Ok(schedule2))
}

pub fn immediate_job_test() {
  let result_subject = process.new_subject()

  let job = fn() {
    let computation = int.sum([1, 2, 3, 4, 5])
    process.send(result_subject, computation)
  }

  let assert Ok(cron) = clockwork.from_string("0 0 1 1 *")

  let scheduler = clockwork_schedule.new("scheduler", cron, job)

  let assert Ok(schedule) = clockwork_schedule.start(scheduler)

  let assert Ok(result) = process.receive(result_subject, 1000)

  clockwork_schedule.stop(schedule)
  assert result == 15
}

pub fn scheduler_with_different_offsets_test() {
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

  let assert Ok(tokyo_schedule) = clockwork_schedule.start(tokyo_scheduler)
  let assert Ok(ny_schedule) = clockwork_schedule.start(ny_scheduler)

  clockwork_schedule.stop(tokyo_schedule)
  clockwork_schedule.stop(ny_schedule)
}
