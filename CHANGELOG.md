# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2025-01-24

### Changed

**BREAKING CHANGES**: This release includes significant API changes that simplify scheduler management by using named processes.

- **`start/2`**: Now requires a `process.Name(Message)` parameter and returns `actor.StartResult(process.Subject(Message))` instead of `Result(Schedule, actor.StartError)`
  - Before: `clockwork_schedule.start(scheduler) -> Result(Schedule, actor.StartError)`
  - After: `clockwork_schedule.start(scheduler, name) -> actor.StartResult(process.Subject(Message))`

- **`supervised/2`**: Now requires a `process.Name(Message)` parameter instead of a `schedule_receiver: process.Subject(Schedule)`
  - Before: `clockwork_schedule.supervised(scheduler, schedule_receiver)`
  - After: `clockwork_schedule.supervised(scheduler, name)`

- **`stop/1`**: Now takes a `process.Name(Message)` instead of a `Schedule` value
  - Before: `clockwork_schedule.stop(schedule)`
  - After: `clockwork_schedule.stop(name)`

### Removed

- **`Schedule` type**: The opaque `Schedule` type has been removed. Schedulers are now controlled using `process.Name(Message)` values directly.

### Added

- Named actor support: All schedulers now run as named actors, simplifying process management and supervision
- Better integration with OTP patterns through named processes

### Migration Guide

To migrate from v1.x to v2.0.0:

1. Import `gleam/erlang/process` in your modules
2. Create process names using `process.new_name("your_scheduler_id")`
3. Pass the name to `start()` or `supervised()`
4. Use the name instead of Schedule handles for `stop()`

Example migration:

```gleam
// v1.x
let assert Ok(schedule) = clockwork_schedule.start(scheduler)
clockwork_schedule.stop(schedule)

// v2.0.0
import gleam/erlang/process
let name = process.new_name("my_scheduler")
let assert Ok(_subject) = clockwork_schedule.start(scheduler, name)
clockwork_schedule.stop(name)
```

## [1.0.0] - 2025-01-23

### Added
- Initial release of clockwork_schedule library
- Core scheduler functionality for managing recurring tasks
- Cron expression support through the Clockwork library
- OTP supervision support for fault-tolerant task scheduling
- Time zone configuration with UTC offset support
- Optional logging for job execution monitoring
- Builder pattern API for scheduler configuration
- Support for multiple concurrent schedulers
- Graceful start and stop mechanisms
- Comprehensive documentation and examples
- Full test coverage with gleeunit

### Features
- `new/3` - Create a new scheduler with id, cron expression, and job function
- `with_logging/1` - Enable logging for scheduler events
- `with_time_offset/2` - Configure scheduler for specific time zones
- `start/1` - Start an unsupervised scheduler
- `supervised/2` - Create child spec for supervised scheduling
- `stop/1` - Gracefully stop a running scheduler

[Unreleased]: https://github.com/renatillas/clockwork_schedule/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/renatillas/clockwork_schedule/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/renatillas/clockwork_schedule/releases/tag/v1.0.0