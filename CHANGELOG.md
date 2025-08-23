# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/renatillas/clockwork_schedule/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/renatillas/clockwork_schedule/releases/tag/v1.0.0